require('dotenv').config();
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

const admin = require('firebase-admin');

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH;
if (serviceAccountPath) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
} else {
    admin.initializeApp({
        credential: admin.credential.applicationDefault(),
    });
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// Password hashing
const bcrypt = require('bcrypt');

// PDF and Email dependencies (Feature 4.2)
const nodemailer = require('nodemailer');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

// Email transporter configuration (Feature 4.2)
// Only create if nodemailer is available
let emailTransporter = null;
if (nodemailer && typeof nodemailer.createTransport === 'function') {
    if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
        emailTransporter = nodemailer.createTransport({
            service: process.env.EMAIL_SERVICE || 'gmail',
            auth: {
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_PASS
            }
        });
        
        // Verify email transporter connection on startup
        emailTransporter.verify(function(error, success) {
            if (error) {
                console.error('❌ Email transporter verification failed:', error.message);
                console.error('   Please check your EMAIL_USER and EMAIL_PASS in .env file');
                console.error('   Make sure you are using a Gmail App Password (not your regular password)');
            } else {
                console.log('✅ Email transporter verified successfully');
            }
        });
    } else {
        console.warn('⚠️ Email not configured. EMAIL_USER or EMAIL_PASS missing in .env');
    }
} else {
    console.warn('⚠️ Email not configured. Invoice emails will be skipped.');
}

// Helper: Generate PDF Invoice (Feature 4.2 by İrem Ulusal)
async function generateInvoicePDF(orderData, userEmail) {
    return new Promise((resolve, reject) => {
        const doc = new PDFDocument();
        const fileName = `invoice_${orderData.order_id}_${Date.now()}.pdf`;
        const filePath = path.join(__dirname, 'temp', fileName);
        
        // Create temp directory if it doesn't exist
        if (!fs.existsSync(path.join(__dirname, 'temp'))) {
            fs.mkdirSync(path.join(__dirname, 'temp'));
        }
        
        const writeStream = fs.createWriteStream(filePath);
        doc.pipe(writeStream);
        
        // PDF Header
        doc.fontSize(20).text('INVOICE', { align: 'center' });
        doc.moveDown();
        
        // Order Information
        doc.fontSize(12);
        doc.text(`Order ID: #${orderData.order_id}`);
        doc.text(`Date: ${new Date().toLocaleString('en-US')}`);
        doc.text(`Customer Email: ${userEmail}`);
        doc.text(`Status: ${orderData.status}`);
        doc.moveDown();
        
        // Items Table Header
        doc.fontSize(14).text('Order Items:', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        
        // Table headers
        doc.text('Product ID', 50, doc.y, { continued: true, width: 80 });
        doc.text('Quantity', 150, doc.y, { continued: true, width: 80 });
        doc.text('Price', 250, doc.y, { continued: false, width: 100 });
        doc.moveDown();
        
        // Items
        orderData.items.forEach(item => {
            const y = doc.y;
            doc.text(item.product_id, 50, y, { continued: true, width: 80 });
            doc.text(item.quantity, 150, y, { continued: true, width: 80 });
            doc.text(`$${item.unit_price || 0}`, 250, y, { continued: false, width: 100 });
            doc.moveDown(0.5);
        });
        
        // Total
        doc.moveDown();
        doc.fontSize(14);
        doc.text(`Total Amount: $${orderData.total_amount.toFixed(2)}`, { align: 'right' });
        
        // Footer
        doc.moveDown(2);
        doc.fontSize(10).text('Thank you for your purchase!', { align: 'center' });
        
        doc.end();
        
        writeStream.on('finish', () => resolve(filePath));
        writeStream.on('error', reject);
    });
}

// Helper: Send Invoice Email (Feature 4.2 by İrem Ulusal)
async function sendInvoiceEmail(userEmail, orderData, pdfPath) {
    // Check if email is configured
    if (!emailTransporter) {
        console.warn('⚠️ Email transporter not available. Skipping email.');
        // Clean up temp PDF file
        try { fs.unlinkSync(pdfPath); } catch(e) {}
        return false;
    }
    
    const mailOptions = {
        from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
        to: userEmail,
        subject: `Invoice for Order #${orderData.order_id}`,
        html: `
            <h2>Thank you for your order!</h2>
            <p>Your order <strong>#${orderData.order_id}</strong> has been confirmed.</p>
            <p><strong>Total Amount:</strong> $${orderData.total_amount.toFixed(2)}</p>
            <p>Please find your invoice attached.</p>
            <br>
            <p>Best regards,<br>CS308 Shop Team</p>
        `,
        attachments: [
            {
                filename: `invoice_${orderData.order_id}.pdf`,
                path: pdfPath
            }
        ]
    };
    
    try {
        const info = await emailTransporter.sendMail(mailOptions);
        console.log(`Invoice email sent to ${userEmail}: ${info.messageId}`);
        
        // Clean up temp PDF file
        fs.unlinkSync(pdfPath);
        
        return true;
    } catch (err) {
        console.error('Email send error:', err);
        // Clean up temp PDF file
        try { fs.unlinkSync(pdfPath); } catch(e) {}
        // Don't throw error - order should still succeed even if email fails
        return false;
    }
}

// --- AUTH MIDDLEWARE ---

function getTokenFromHeader(req) {
    const h = req.header('Authorization') || '';
    if (!h.startsWith('Bearer ')) return null;
    return h.split(' ')[1];
}

async function authenticate(req, res, next) {
    const token = getTokenFromHeader(req);
    if (!token) return res.status(401).json({ error: 'Missing auth token' });

    // FIX: Allow Seeded User IDs (simple numbers)
    if (/^\d+$/.test(token)) {
        try {
            const doc = await db.collection('users').doc(token).get();
            if (doc.exists) {
                req.user = { uid: token, role: doc.data().role || 'customer' };
                return next();
            }
        } catch (e) {
            console.log("Seeded user auth failed", e);
        }
    }

    // Fallback to Firebase Auth for real users
    try {
        const decoded = await admin.auth().verifyIdToken(token);
        req.user = { uid: decoded.uid, claims: decoded };
        try {
            const doc = await db.collection('users').doc(decoded.uid).get();
            if (doc.exists) {
                req.user.role = doc.data().role || decoded.role || null;
            }
        } catch (e) { }
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid auth token', details: err.message });
    }
}

function authorize(allowedRoles = []) {
    return (req, res, next) => {
        if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
        if (!allowedRoles.length) return next();
        if (allowedRoles.includes(req.user.role)) return next();
        return res.status(403).json({ error: 'Forbidden - insufficient role' });
    };
}

// --- EXISTING ENDPOINTS ---

app.get('/health', (req, res) => {
    return res.json({ status: 'ok' });
});
app.get('/collections', async (req, res) => {
    try {
        const firestore = admin.firestore();
        const collections = await firestore.listCollections();
        const names = collections.map((c) => c.id);
        return res.json({ collections: names });
    } catch (err) {
        console.error('Failed to list collections:', err);
        return res.status(500).json({ error: 'Failed to list collections' });
    }
});
app.get('/collections/:name', async (req, res) => {
    const { name } = req.params;
    try {
        const firestore = admin.firestore();
        const collectionRef = firestore.collection(name);
        let query = collectionRef.limit(20);

        // Public endpoints should never surface unapproved reviews
        if (name === 'reviews') {
            query = collectionRef.where('approval_status', '==', 'approved').limit(20);
        }

        const snapshot = await query.get();
        const documents = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        return res.json({ collection: name, count: documents.length, documents });
    } catch (err) {
        console.error(`Failed to read collection ${name}:`, err);
        return res.status(500).json({ error: `Failed to read collection ${name}` });
    }
});
app.get('/', (req, res) => {
    return res.json({
        message: 'Backend is running',
        endpoints: [
            '/health',
            '/collections',
            '/collections/:name',
            '/login',
            '/register',
            '/logout - Save cart and logout (Feature 4.1.2)',
            '/users/:uid/cart - GET/POST saved cart (Feature 4.1.2)',
            '/checkout - Creates order & sends PDF invoice email (Feature 4.2)',
            '/orders/delivery',
            '/products/:id/reviews',
            '/reviews/moderation',
            '/reviews/:id/approve',
            '/roles',
            '/users/:id/role',
            '/users/:uid/orders',
            '/products/:id/reviews',
            '/my-pending-reviews',
            '/reviews - POST/DELETE',
            '/auth/* - Login-Sign Up routes'
        ]
    });
});
// Login endpoint
app.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({
                error: 'Email and password are required',
                details: 'Please provide both email and password in the request body'
            });
        }

        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('email', '==', email).limit(1).get();

        if (snapshot.empty) {
            return res.status(401).json({
                error: 'Invalid credentials',
                details: 'No user found with this email'
            });
        }

        const userDoc = snapshot.docs[0];
        const userData = userDoc.data();

        // Check if password is hashed (starts with $2b$) or plain text
        let isPasswordValid = false;
        if (userData.password && userData.password.startsWith('$2b$')) {
            // Password is hashed, use bcrypt.compare
            isPasswordValid = await bcrypt.compare(password, userData.password);
        } else {
            // Password is plain text (for backward compatibility with old data)
            isPasswordValid = userData.password === password;
        }

        if (!isPasswordValid) {
            return res.status(401).json({
                error: 'Invalid credentials',
                details: 'Incorrect password'
            });
        }

        const { password: _, ...userWithoutPassword } = userData;
        return res.json({
            success: true,
            message: 'Login successful',
            user: {
                id: userDoc.id,
                ...userWithoutPassword
            }
        });
    } catch (err) {
        console.error('Login error:', err);
        return res.status(500).json({
            error: 'Failed to process login',
            details: err.message
        });
    }
});

// Register endpoint
app.post('/register', async (req, res) => {
    try {
        const { email, password, name, address } = req.body;

        if (!email || !password || !name) {
            return res.status(400).json({
                error: 'Missing required fields',
                details: 'Email, password, and name are required. Address is optional.'
            });
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({
                error: 'Invalid email format',
                details: 'Please provide a valid email address'
            });
        }

        if (password.length < 6) {
            return res.status(400).json({
                error: 'Password too short',
                details: 'Password must be at least 6 characters long'
            });
        }

        const usersRef = db.collection('users');
        const emailCheck = await usersRef.where('email', '==', email).limit(1).get();
        if (!emailCheck.empty) {
            return res.status(409).json({
                error: 'Email already registered',
                details: 'A user with this email already exists'
            });
        }

        const allUsers = await usersRef.get();
        let maxUserId = 0;
        allUsers.forEach(doc => {
            const userId = doc.data().user_id;
            if (userId && userId > maxUserId) {
                maxUserId = userId;
            }
        });
        const newUserId = maxUserId + 1;

        // Hash the password before storing
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);

        const newUser = {
            user_id: newUserId,
            email: email,
            password: hashedPassword, // Store hashed password
            name: name,
            address: address || '',
        };

        await usersRef.doc(String(newUserId)).set(newUser);

        const { password: _, ...userWithoutPassword } = newUser;
        return res.status(201).json({
            success: true,
            message: 'User registered successfully',
            user: {
                id: String(newUserId),
                ...userWithoutPassword
            }
        });
    } catch (err) {
        console.error('Register error:', err);
        return res.status(500).json({
            error: 'Failed to register user',
            details: err.message
        });
    }
});

// Checkout endpoint
app.post('/checkout', async (req, res) => {
    try {
        const { user_id, items } = req.body || {};

        if (!user_id) {
            return res.status(400).json({
                error: 'Missing user_id',
                details: 'Please provide the user_id placing the order'
            });
        }

        if (!Array.isArray(items) || !items.length) {
            return res.status(400).json({
                error: 'Missing items',
                details: 'Provide at least one product with product_id and quantity'
            });
        }

        const sanitizedItems = [];
        const aggregated = {};
        for (const entry of items) {
            const { product_id, quantity } = entry || {};
            const productIdNum = Number(product_id);
            const quantityNum = Number(quantity);
            if (!Number.isInteger(productIdNum) || productIdNum <= 0) {
                return res.status(400).json({
                    error: 'Invalid product_id',
                    details: 'Each item must include a positive integer product_id'
                });
            }
            if (!Number.isInteger(quantityNum) || quantityNum <= 0) {
                return res.status(400).json({
                    error: 'Invalid quantity',
                    details: 'Each item must include a positive integer quantity'
                });
            }
            sanitizedItems.push({ product_id: productIdNum, quantity: quantityNum });
            const key = String(productIdNum);
            aggregated[key] = (aggregated[key] || 0) + quantityNum;
        }

        const normalizedUserId = /^\d+$/.test(String(user_id)) ? Number(user_id) : user_id;

        const initialStatus = 'processing';

        const orderResult = await db.runTransaction(async (tx) => {
            const productEntries = Object.entries(aggregated);
            const productRefs = productEntries.map(([productId]) =>
                db.collection('products').doc(String(productId))
            );
            const productSnaps = await Promise.all(productRefs.map((ref) => tx.get(ref)));

            const countersRef = db.collection('meta').doc('counters');
            const countersSnap = await tx.get(countersRef);
            let orderId;
            if (countersSnap.exists && typeof countersSnap.data().nextOrderId === 'number') {
                orderId = countersSnap.data().nextOrderId;
                tx.update(countersRef, { nextOrderId: orderId + 1 });
            } else {
                orderId = 1;
                tx.set(countersRef, { nextOrderId: 2 }, { merge: true });
            }

            let computedTotal = 0;
            productSnaps.forEach((snap, index) => {
                const [productId, requestedQty] = productEntries[index];
                if (!snap.exists) {
                    const error = new Error(`Product ${productId} not found`);
                    error.code = 'PRODUCT_NOT_FOUND';
                    error.meta = { productId };
                    throw error;
                }
                const data = snap.data();
                const currentStock = Number(data.quantity_in_stock || 0);
                if (currentStock < requestedQty) {
                    const error = new Error(`Product ${productId} does not have enough stock`);
                    error.code = 'OUT_OF_STOCK';
                    error.meta = { productId, available: currentStock };
                    throw error;
                }
                const price = Number(data.price || 0);
                computedTotal += price * requestedQty;
                tx.update(productRefs[index], {
                    quantity_in_stock: FieldValue.increment(-requestedQty)
                });
            });

            const orderRef = db.collection('orders').doc(String(orderId));
            const orderPayload = {
                order_id: orderId,
                user_id: normalizedUserId,
                status: initialStatus,
                total_amount: Number(computedTotal.toFixed(2)),
                items: sanitizedItems,
                created_at: FieldValue.serverTimestamp()
            };
            tx.set(orderRef, orderPayload);

            return { id: orderRef.id, ...orderPayload };
        });

        // Feature 4.2: Send PDF Invoice Email
        try {
            // Get user email
            const userDoc = await db.collection('users').doc(String(normalizedUserId)).get();
            const userEmail = userDoc.exists ? userDoc.data().email : null;
            
            if (userEmail && process.env.EMAIL_USER) {
                // Generate PDF invoice
                const pdfPath = await generateInvoicePDF(orderResult, userEmail);
                
                // Send email with PDF attachment
                await sendInvoiceEmail(userEmail, orderResult, pdfPath);
                
                console.log(`✅ Invoice sent to ${userEmail} for order #${orderResult.order_id}`);
            } else {
                console.warn('⚠️ Email not configured or user email not found. Skipping invoice email.');
            }
        } catch (emailErr) {
            // Don't fail the order if email fails
            console.error('Invoice email error (non-critical):', emailErr.message);
        }
        
        return res.status(201).json({
            success: true,
            message: 'Order created and stock updated',
            order: orderResult
        });
    } catch (err) {
        console.error('Checkout error:', err);
        if (err.code === 'OUT_OF_STOCK') {
            return res.status(409).json({
                error: 'Insufficient stock',
                details: err.message,
                product: err.meta
            });
        }
        if (err.code === 'PRODUCT_NOT_FOUND') {
            return res.status(404).json({
                error: 'Product not found',
                details: err.message,
                product: err.meta
            });
        }
        return res.status(500).json({
            error: 'Failed to process checkout',
            details: err.message
        });
    }
});

// Delivery queue endpoint
app.get('/orders/delivery', authenticate, authorize(['product_manager']), async (req, res) => {
    try {
        const snapshot = await db.collection('orders')
            .where('status', 'in', ['processing', 'in-transit'])
            .get();

        const orders = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.json({ orders });
    } catch (err) {
        console.error('Delivery queue error:', err);
        return res.status(500).json({
            error: 'Failed to load delivery queue',
            details: err.message
        });
    }
});

app.get('/roles', async (req, res) => {
    try {
        const rolesCol = await db.collection('roles').get();
        if (!rolesCol.empty) {
            const roles = rolesCol.docs.map(d => ({ id: d.id, ...d.data() }));
            return res.json({ roles });
        }
        const users = await db.collection('users').get();
        const set = new Set();
        users.forEach(d => {
            const r = d.data().role;
            if (r) set.add(r);
        });
        return res.json({ roles: Array.from(set) });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to list roles', details: err.message });
    }
});
app.get('/users/:id/role', authenticate, authorize(['admin']), async (req, res) => {
    const uid = req.params.id;
    try {
        const doc = await db.collection('users').doc(uid).get();
        const role = doc.exists ? doc.data().role || null : null;
        return res.json({ uid, role });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to get user role', details: err.message });
    }
});
app.put('/users/:id/role', authenticate, authorize(['admin']), async (req, res) => {
    const uid = req.params.id;
    const { role } = req.body || {};
    if (!role) return res.status(400).json({ error: 'role is required in body' });
    try {
        await db.collection('users').doc(uid).set({ role }, { merge: true });
        await admin.auth().setCustomUserClaims(uid, { role });
        return res.json({ uid, role });
    } catch (err) {
        return res.status(500).json({
            error: 'Failed to set role', details: err.message
        });
    }
});

// --- ORDER ENDPOINTS ---

// GET /users/:uid/orders
// Returns sorted order history with product information
app.get('/users/:uid/orders', authenticate, async (req, res) => {
    const uid = req.params.uid;
    if (req.user.uid !== uid && req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized access to order history' });
    }

    const uidQuery = /^\d+$/.test(uid) ? parseInt(uid, 10) : uid;

    try {
        let ordersSnapshot;
        let snapshotOrdered = true;
        try {
            ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', uidQuery)
                .orderBy('created_at', 'desc')
                .get();
        } catch (orderingError) {
            console.warn('orders created_at index missing, falling back to unsorted query', orderingError.message);
            snapshotOrdered = false;
            ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', uidQuery)
                .get();
        }

        const orders = [];
        for (const orderDoc of ordersSnapshot.docs) {
            const orderData = orderDoc.data();
            const orderId = orderData.order_id;

            let items = [];
            if (Array.isArray(orderData.items) && orderData.items.length) {
                items = orderData.items;
            } else {
                const itemsSnapshot = await db.collection('order_items')
                    .where('order_id', '==', orderId)
                    .get();
                items = itemsSnapshot.docs.map(doc => doc.data());
            }

            const enrichedItems = [];
            for (const item of items) {
                const productId = item.product_id ?? item.productId;
                let productDetails = {};
                if (productId !== undefined) {
                    try {
                        const productDoc = await db.collection('products').doc(String(productId)).get();
                        if (productDoc.exists) {
                            productDetails = productDoc.data();
                        }
                    } catch (e) {
                        console.error('Product fetch error:', e);
                    }
                }
                enrichedItems.push({
                    ...productDetails,
                    ...item,
                    name: item.name || productDetails.name || 'Unknown Product'
                });
            }

            const createdAt = orderData.created_at && typeof orderData.created_at.toDate === 'function'
                ? orderData.created_at.toDate().toISOString()
                : (orderData.date || new Date().toISOString());

            orders.push({
                ...orderData,
                items: enrichedItems,
                date: createdAt
            });
        }

        if (!snapshotOrdered) {
            orders.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
        }

        return res.json({ orders });
    } catch (err) {
        console.error('orders history error:', err);
        return res.status(500).json({ error: err.message });
    }
});

// GET /users/:uid/products/:productId/eligibility
// NEW: Checks if a user has ordered a specific product and if it is delivered
app.get('/users/:uid/products/:productId/eligibility', authenticate, async (req, res) => {
    const { uid, productId } = req.params;

    // Security Check
    if (req.user.uid !== uid && req.user.role !== 'admin') {
        return res.status(403).json({ error: "Unauthorized" });
    }

    const uidQuery = /^\d+$/.test(uid) ? parseInt(uid) : uid;
    const pidQuery = /^\d+$/.test(productId) ? parseInt(productId) : productId;

    try {
        // 1. Get all DELIVERED orders for this user
        const ordersSnapshot = await db.collection('orders')
            .where('user_id', '==', uidQuery)
            .where('status', '==', 'delivered')
            .get();

        if (ordersSnapshot.empty) {
            return res.json({ canReview: false });
        }

        let canReview = false;

        // 2. Check each order's items
        for (const orderDoc of ordersSnapshot.docs) {
            const orderId = orderDoc.data().order_id;

            // Check if this specific product is in this order's items
            const itemSnapshot = await db.collection('order_items')
                .where('order_id', '==', orderId)
                .where('product_id', '==', pidQuery)
                .limit(1)
                .get();

            if (!itemSnapshot.empty) {
                canReview = true;
                break;
            }
        }

        return res.json({ canReview });

    } catch (err) {
        console.error("Eligibility check error:", err);
        return res.status(500).json({ error: err.message });
    }
});

// --- NEW ENDPOINTS FOR REVIEWS (Fixing Gaps 1, 2, 3) ---

// 1. GET Public Reviews for a Product
app.get('/products/:id/reviews', async (req, res) => {
    const productId = req.params.id;
    // Handle integer IDs from seed data if mixed with string IDs
    const pidInt = parseInt(productId);
    const pidQuery = isNaN(pidInt) ? productId : pidInt;

    try {
        const snapshot = await db.collection('reviews')
            .where('product_id', '==', pidQuery)
            .where('approval_status', '==', 'approved')
            // .orderBy('timestamp', 'desc') // Uncomment if you create the composite index in Firebase Console
            .get();

        const reviews = [];
        snapshot.forEach(doc => reviews.push(doc.data()));

        // Manual sort in case index is missing
        reviews.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0));

        return res.json({ reviews });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: err.message });
    }
});

// 2. GET Pending Reviews (Authenticated User Only)
app.get('/my-pending-reviews', authenticate, async (req, res) => {
    try {
        const snapshot = await db.collection('reviews')
            .where('user_id', '==', req.user.uid)
            .where('approval_status', '==', 'pending')
            .get();

        const reviews = [];
        snapshot.forEach(doc => reviews.push(doc.data()));

        return res.json({ reviews });
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});
// 3. POST Review (Secure Status Logic + User Name)
app.post('/reviews', authenticate, async (req, res) => {
    const { product_id, rating, comment } = req.body;

    if (!product_id || !rating) {
        return res.status(400).json({ error: "Missing product_id or rating" });
    }

    const userId = req.user.uid;

    // Handle product ID type consistency
    const pidInt = parseInt(product_id);
    const finalProductId = isNaN(pidInt) ? product_id : pidInt;

    try {
        // Fetch user name for display purposes
        const userDoc = await db.collection('users').doc(userId).get();
        const userName = userDoc.exists ? (userDoc.data().name || "Customer") : "Customer";

        const cleanComment = comment ? comment.trim() : "";
        const approvalStatus = 'pending';

        const newReview = {
            review_id: Date.now().toString(), // Simple ID generation
            user_id: userId,
            author_name: userName, // Saved for display
            product_id: finalProductId,
            rating: Number(rating),
            comment: cleanComment,
            status: approvalStatus,
            approval_status: approvalStatus,
            moderated_by: null,
            approval_reason: null,
            timestamp: new Date().toISOString()
        };
        await db.collection('reviews').doc(newReview.review_id).set(newReview);
        return res.json({ success: true, review: newReview });

    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});

// 3b. GET Pending Reviews for Moderation (Product Manager only)
app.get('/reviews/moderation', authenticate, authorize(['product_manager']), async (req, res) => {
    try {
        const snapshot = await db.collection('reviews')
            .where('approval_status', '==', 'pending')
            .get();

        const reviews = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.json({ reviews });
    } catch (err) {
        console.error('Failed to load pending reviews:', err);
        return res.status(500).json({ error: 'Failed to load pending reviews', details: err.message });
    }
});

// 3c. PUT Approve/Reject Review (Product Manager only)
app.put('/reviews/:id/approve', authenticate, authorize(['product_manager']), async (req, res) => {
    const reviewId = req.params.id;
    const { decision, reason } = req.body || {};
    const normalizedDecision = (decision || 'approved').toLowerCase();

    if (!['approved', 'rejected'].includes(normalizedDecision)) {
        return res.status(400).json({ error: 'Invalid decision', details: 'Use approved or rejected' });
    }

    try {
        const reviewRef = db.collection('reviews').doc(reviewId);
        const reviewDoc = await reviewRef.get();

        if (!reviewDoc.exists) {
            return res.status(404).json({ error: 'Review not found' });
        }

        const updatePayload = {
            approval_status: normalizedDecision,
            status: normalizedDecision,
            moderated_by: req.user.uid,
            approval_reason: reason || null,
            moderated_at: FieldValue.serverTimestamp()
        };

        await reviewRef.update(updatePayload);
        const updatedDoc = await reviewRef.get();
        return res.json({ success: true, review: updatedDoc.data() });
    } catch (err) {
        console.error('Failed to update review approval:', err);
        return res.status(500).json({ error: 'Failed to update review approval', details: err.message });
    }
});

// 4. DELETE Review (Owner Only)
app.delete('/reviews/:id', authenticate, async (req, res) => {
    const reviewId = req.params.id;
    try {
        const docRef = db.collection('reviews').doc(reviewId);
        const doc = await docRef.get();

        if (!doc.exists) return res.status(404).json({ error: "Review not found" });

        // Security Check: Only owner can delete
        if (doc.data().user_id !== req.user.uid) {
            return res.status(403).json({ error: "Unauthorized" });
        }

        await docRef.delete();
        return res.json({ success: true });
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});

// ============================================
// CART ENDPOINTS (Feature 4.1.2 by İrem Ulusal)
// ============================================

// POST /users/:uid/cart - Save cart to user account
app.post('/users/:uid/cart', authenticate, async (req, res) => {
    const uid = req.params.uid;
    const { items } = req.body;
    
    // Security check
    if (req.user.uid !== uid) {
        return res.status(403).json({ error: 'Unauthorized' });
    }
    
    try {
        await db.collection('users').doc(uid).set({
            saved_cart: items || []
        }, { merge: true });
        
        return res.json({
            success: true,
            message: 'Cart saved successfully'
        });
    } catch (err) {
        console.error('Save cart error:', err);
        return res.status(500).json({
            error: 'Failed to save cart',
            details: err.message
        });
    }
});

// GET /users/:uid/cart - Get saved cart from user account
app.get('/users/:uid/cart', authenticate, async (req, res) => {
    const uid = req.params.uid;
    
    // Security check
    if (req.user.uid !== uid) {
        return res.status(403).json({ error: 'Unauthorized' });
    }
    
    try {
        const userDoc = await db.collection('users').doc(uid).get();
        
        if (!userDoc.exists) {
            return res.json({ cart: [] });
        }
        
        const cart = userDoc.data().saved_cart || [];
        return res.json({ cart });
    } catch (err) {
        console.error('Get cart error:', err);
        return res.status(500).json({
            error: 'Failed to get cart',
            details: err.message
        });
    }
});

// POST /logout - Save cart and logout (Feature 4.1.2)
app.post('/logout', authenticate, async (req, res) => {
    const { cart } = req.body;
    const uid = req.user.uid;
    
    try {
        // Save cart to user account before logout
        if (cart && Array.isArray(cart)) {
            await db.collection('users').doc(uid).set({
                saved_cart: cart
            }, { merge: true });
        }
        
        return res.json({
            success: true,
            message: 'Cart saved and logged out successfully'
        });
    } catch (err) {
        console.error('Logout error:', err);
        return res.status(500).json({
            error: 'Failed to logout',
            details: err.message
        });
    }
});

// ============================================
// AUTH ROUTES (Login-Sign Up by İrem Ulusal)
// ============================================
require('./auth-routes')(app, db);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
});
