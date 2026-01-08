require('dotenv').config();
const express = require('express');
const cors = require('cors');
const app = express();
const jwt = require('jsonwebtoken');

app.use(cors());
app.use(express.json());

const admin = require('firebase-admin');
const JWT_SECRET = process.env.JWT_SECRET || 'cs308-secret-key-change-in-production';

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH || './my-firebase.json';
if (admin.apps.length === 0) {
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
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const bucket = admin.storage().bucket('cs308db.firebasestorage.app');

const bcrypt = require('bcrypt');
const nodemailer = require('nodemailer');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const { encrypt, decrypt, encryptFields, decryptFields } = require('./encryption');

// Email transporter configuration
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
        emailTransporter.verify(function (error, success) {
            if (error) {
                console.error('❌ Email transporter verification failed:', error.message);
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

// Helper: Generate PDF Invoice
async function generateInvoicePDF(orderData, userEmail) {
    return new Promise((resolve, reject) => {
        const doc = new PDFDocument();
        const fileName = `invoice_${orderData.order_id}_${Date.now()}.pdf`;
        const dirPath = path.join(__dirname, 'temp');

        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath);
        }

        const filePath = path.join(dirPath, fileName);

        const writeStream = fs.createWriteStream(filePath);
        doc.pipe(writeStream);

        doc.fontSize(20).text('INVOICE', { align: 'center' });
        doc.moveDown();

        doc.fontSize(12);
        doc.text(`Order ID: #${orderData.order_id}`);
        doc.text(`Date: ${new Date().toLocaleString('en-US')}`);
        doc.text(`Customer Email: ${userEmail}`);
        doc.text(`Status: ${orderData.status}`);
        doc.moveDown();

        doc.fontSize(14).text('Order Items:', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        doc.text('Product ID', 50, doc.y, { continued: true, width: 80 });
        doc.text('Quantity', 150, doc.y, { continued: true, width: 80 });
        doc.text('Price', 250, doc.y, { continued: false, width: 100 });
        doc.moveDown();
        if (orderData.items && Array.isArray(orderData.items)) {
            orderData.items.forEach(item => {
                const y = doc.y;
                doc.text(item.product_id, 50, y, { continued: true, width: 80 });
                doc.text(item.quantity, 150, y, { continued: true, width: 80 });
                doc.text(`$${item.unit_price || 0}`, 250, y, { continued: false, width: 100 });
                doc.moveDown(0.5);
            });
        }

        doc.moveDown();
        doc.fontSize(14);
        doc.text(`Total Amount: $${orderData.total_amount.toFixed(2)}`, { align: 'right' });

        doc.moveDown(2);
        doc.fontSize(10).text('Thank you for your purchase!', { align: 'center' });

        doc.end();

        writeStream.on('finish', () => resolve(filePath));
        writeStream.on('error', reject);
    });
}

// Helper: Send Invoice Email
async function sendInvoiceEmail(userEmail, orderData, pdfPath) {
    if (!emailTransporter) {
        try {
            fs.unlinkSync(pdfPath);
        } catch (e) { }
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
        fs.unlinkSync(pdfPath);
        return true;
    } catch (err) {
        console.error('Email send error:', err);
        try { fs.unlinkSync(pdfPath); } catch (e) { }
        return false;
    }
}

function getTokenFromHeader(req) {
    const h = req.header('Authorization') || '';
    if (!h.startsWith('Bearer ')) return null;
    return h.split(' ')[1];
}

async function authenticate(req, res, next) {
    const token = getTokenFromHeader(req);
    if (!token) return res.status(401).json({ error: 'Missing auth token' });

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

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = {
            uid: decoded.user_id,
            user_id: decoded.user_id,
            role: decoded.role,
            email: decoded.email,
            ...decoded
        };
        return next();
    } catch (jwtErr) {
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
        } catch (firebaseErr) {
            return res.status(401).json({ error: 'Invalid auth token', details: firebaseErr.message });
        }
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

// Optional authenticate - tries to authenticate but doesn't fail if no token
function optionalAuthenticate(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        // No token provided, continue as guest
        req.user = null;
        return next();
    }

    const token = authHeader.substring(7);

    // Try seeded user first (user_id as token)
    if (/^\d+$/.test(token)) {
        db.collection('users').doc(token).get()
            .then(doc => {
                if (doc.exists) {
                    req.user = { uid: token, role: doc.data().role || 'customer' };
                } else {
                    req.user = null;
                }
                return next();
            })
            .catch(() => {
                req.user = null;
                return next();
            });
        return;
    }

    // Try JWT
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = {
            uid: decoded.user_id,
            user_id: decoded.user_id,
            role: decoded.role,
            email: decoded.email,
            ...decoded
        };
        return next();
    } catch (jwtErr) {
        // Try Firebase token
        admin.auth().verifyIdToken(token)
            .then(async (decoded) => {
                req.user = { uid: decoded.uid, claims: decoded };
                try {
                    const doc = await db.collection('users').doc(decoded.uid).get();
                    if (doc.exists) {
                        req.user.role = doc.data().role || decoded.role || null;
                    }
                } catch (e) { }
                next();
            })
            .catch(() => {
                // Invalid token, continue as guest
                req.user = null;
                next();
            });
    }
}

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

        if (name === 'reviews') {
            query = collectionRef.where('approval_status', '==', 'approved').limit(20);
        }

        const snapshot = await query.get();
        let documents = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

        if (name === 'products') {
            const productIds = documents.map(doc => {
                const pid = doc.product_id ?? doc.id;
                return typeof pid === 'number' ? pid : parseInt(pid);
            }).filter(pid => !isNaN(pid));

            const reviewsPromises = productIds.map(async (pid) => {
                try {
                    const reviewsSnapshot = await db.collection('reviews')
                        .where('product_id', '==', pid)
                        .where('approval_status', '==', 'approved')
                        .get();
                    const reviews = [];
                    reviewsSnapshot.forEach(doc => reviews.push(doc.data()));

                    if (reviews.length === 0) {
                        return { productId: pid, averageRating: 0, reviewCount: 0 };
                    }

                    const totalRating = reviews.reduce((sum, r) => sum + (r.rating || 0), 0);
                    const averageRating = totalRating / reviews.length;

                    return {
                        productId: pid,
                        averageRating: Math.round(averageRating * 10) / 10,
                        reviewCount: reviews.length
                    };
                } catch (e) {
                    return { productId: pid, averageRating: 0, reviewCount: 0 };
                }
            });

            const ratingsData = await Promise.all(reviewsPromises);
            const ratingsMap = {};
            ratingsData.forEach(r => {
                ratingsMap[r.productId] = { averageRating: r.averageRating, reviewCount: r.reviewCount };
            });
            documents = documents.map(doc => {
                const pid = doc.product_id ?? doc.id;
                const pidNum = typeof pid === 'number' ? pid : parseInt(pid);
                const ratingInfo = ratingsMap[pidNum] || { averageRating: 0, reviewCount: 0 };

                const existingPopularity = doc.popularity_score ?? 0;
                const calculatedPopularity = ratingInfo.reviewCount > 0
                    ? (ratingInfo.averageRating * ratingInfo.reviewCount) / 10
                    : 0;
                const popularityScore = existingPopularity > 0 ? existingPopularity : calculatedPopularity;

                // Convert Firebase Storage URL to proxy URL if exists
                let imageUrl = doc.image_url;
                if (imageUrl && typeof imageUrl === 'string') {
                    // Extract filename from Firebase Storage URL (handle both encoded and plain paths)
                    const urlMatch = imageUrl.match(/products[%2F\/]([^?&]+)/);
                    if (urlMatch) {
                        const filename = decodeURIComponent(urlMatch[1].replace(/%2F/g, '/'));
                        imageUrl = `${req.protocol}://${req.get('host')}/images/${encodeURIComponent(filename)}`;
                    }
                }
                
                return {
                    ...doc,
                    image_url: imageUrl,
                    average_rating: ratingInfo.averageRating,
                    review_count: ratingInfo.reviewCount,
                    popularity_score: popularityScore
                };
            });
        }

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
            '/checkout',
            '/orders/delivery',
            '/products/:id/reviews',
            '/reviews/moderation',
            '/reviews/:id/approve',
            '/roles',
            '/users/:id/role',
            '/users/:uid/orders',
            '/my-pending-reviews',
            '/reviews',
            '/auth/*'
        ]
    });
});
app.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }
        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('email', '==', email).limit(1).get();

        if (snapshot.empty) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const userDoc = snapshot.docs[0];
        const userData = userDoc.data();

        let isPasswordValid = false;
        if (userData.password && userData.password.startsWith('$2b$')) {
            isPasswordValid = await bcrypt.compare(password, userData.password);
        } else {
            isPasswordValid = userData.password === password;
        }

        if (!isPasswordValid) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const { password: _, ...userWithoutPassword } = userData;
        return res.json({
            success: true,
            message: 'Login successful',
            user: { id: userDoc.id, ...userWithoutPassword }
        });
    } catch (err) {
        console.error('Login error:', err);
        return res.status(500).json({ error: 'Failed to process login' });
    }
});

app.post('/register', async (req, res) => {
    try {
        const { email, password, name, address } = req.body;
        if (!email || !password || !name) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ error: 'Invalid email format' });
        }
        if (password.length < 6) {
            return res.status(400).json({ error: 'Password too short' });
        }

        const usersRef = db.collection('users');
        const emailCheck = await usersRef.where('email', '==', email).limit(1).get();
        if (!emailCheck.empty) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        const allUsers = await usersRef.get();
        let maxUserId = 0;
        allUsers.forEach(doc => {
            const userId = doc.data().user_id;
            if (userId && userId > maxUserId) maxUserId = userId;
        });
        const newUserId = maxUserId + 1;

        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);

        const newUser = {
            user_id: newUserId,
            email: email,
            password: hashedPassword,
            name: name,
            address: address || '',
            role: 'customer',
            created_at: new Date().toISOString()
        };
        await usersRef.doc(String(newUserId)).set(newUser);
        const { password: _, ...userWithoutPassword } = newUser;
        return res.status(201).json({
            success: true,
            message: 'User registered successfully',
            user: { id: String(newUserId), ...userWithoutPassword }
        });
    } catch (err) {
        console.error('Register error:', err);
        return res.status(500).json({ error: 'Failed to register user' });
    }
});

app.post('/checkout', async (req, res) => {
    try {
        const { user_id, items } = req.body || {};
        if (!user_id) return res.status(400).json({ error: 'Missing user_id' });
        if (!Array.isArray(items) || !items.length) return res.status(400).json({ error: 'Missing items' });

        const sanitizedItems = [];
        const aggregated = {};
        for (const entry of items) {
            const { product_id, quantity } = entry || {};
            const productIdNum = Number(product_id);
            const quantityNum = Number(quantity);

            if (!Number.isInteger(productIdNum) || productIdNum <= 0) return res.status(400).json({ error: 'Invalid product_id' });
            if (!Number.isInteger(quantityNum) || quantityNum <= 0) return res.status(400).json({ error: 'Invalid quantity' });

            sanitizedItems.push({ product_id: productIdNum, quantity: quantityNum });
            const key = String(productIdNum);
            aggregated[key] = (aggregated[key] || 0) + quantityNum;
        }

        const normalizedUserId = /^\d+$/.test(String(user_id)) ? Number(user_id) : user_id;
        const initialStatus = 'processing';

        // Get user's current address BEFORE transaction (Firestore requires all reads before writes)
        let deliveryAddress = 'N/A';
        try {
            const userDoc = await db.collection('users').doc(String(normalizedUserId)).get();
            if (userDoc.exists) {
                deliveryAddress = userDoc.data().address || 'N/A';
            }
        } catch (err) {
            console.error('Error fetching user address for order:', err);
        }

        const orderResult = await db.runTransaction(async (tx) => {
            const productEntries = Object.entries(aggregated);
            const productRefs = productEntries.map(([productId]) => db.collection('products').doc(String(productId)));
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

            const priceMap = {};

            let computedTotal = 0;
            productSnaps.forEach((snap, index) => {
                const [productId, requestedQty] = productEntries[index];
                if (!snap.exists) throw new Error(`Product ${productId} not found`);

                const data = snap.data();
                const currentStock = Number(data.quantity_in_stock || 0);
                if (currentStock < requestedQty) throw new Error(`Product ${productId} out of stock`);

                const price = Number(data.price || 0);
                priceMap[productId] = price;

                computedTotal += price * requestedQty;
                tx.update(productRefs[index], { quantity_in_stock: FieldValue.increment(-requestedQty) });
            });

            const itemsWithPrice = sanitizedItems.map(item => ({
                ...item,
                unit_price: priceMap[String(item.product_id)] || 0
            }));
            
            const orderRef = db.collection('orders').doc(String(orderId));
            const orderPayload = {
                order_id: orderId,
                user_id: normalizedUserId,
                status: initialStatus,
                total_amount: Number(computedTotal.toFixed(2)),
                items: itemsWithPrice,
                delivery_address: deliveryAddress, // Store current user address
                created_at: FieldValue.serverTimestamp(),
                date: FieldValue.serverTimestamp() // Use server timestamp for date too
            };
            tx.set(orderRef, orderPayload);
            return { id: orderRef.id, ...orderPayload };
        });

        try {
            const userDoc = await db.collection('users').doc(String(normalizedUserId)).get();
            const userEmail = userDoc.exists ? userDoc.data().email : null;
            if (userEmail && process.env.EMAIL_USER) {
                const pdfPath = await generateInvoicePDF(orderResult, userEmail);
                await sendInvoiceEmail(userEmail, orderResult, pdfPath);
            }
        } catch (emailErr) {
            console.error('Invoice email error:', emailErr.message);
        }

        return res.status(201).json({ success: true, message: 'Order created', order: orderResult });
    } catch (err) {
        console.error('Checkout error:', err);
        return res.status(500).json({ error: 'Checkout failed', details: err.message });
    }
});

app.get('/orders/delivery', authenticate, authorize(['product_manager']), async (req, res) => {
    try {
        const snapshot = await db.collection('orders')
            .where('status', 'in', ['processing', 'in-transit', 'delivered'])
            .get();

        const orders = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        orders.sort((a, b) => {
            const statusPriority = {
                'processing': 1,
                'in-transit': 2,
                'delivered': 3
            };
            return (statusPriority[a.status] || 999) - (statusPriority[b.status] || 999);
        });

        return res.json({ orders });
    } catch (err) {
        console.error('Delivery queue error:', err);
        return res.status(500).json({ error: 'Failed to load delivery queue' });
    }
});

app.put('/orders/:orderId/status', authenticate, authorize(['product_manager']), async (req, res) => {
    const { orderId } = req.params;
    const { status } = req.body;

    const validStatuses = ['processing', 'in-transit', 'delivered', 'cancelled'];
    if (!status || !validStatuses.includes(status)) {
        return res.status(400).json({ error: 'Invalid status. Valid values: processing, in-transit, delivered, cancelled' });
    }

    try {
        const orderRef = db.collection('orders').doc(orderId);
        const orderDoc = await orderRef.get();

        if (!orderDoc.exists) {
            return res.status(404).json({ error: 'Order not found' });
        }

        await orderRef.update({
            status: status,
            updated_at: FieldValue.serverTimestamp()
        });

        const updatedDoc = await orderRef.get();

        return res.json({ success: true, order: updatedDoc.data() });
    } catch (err) {
        console.error('Update order status error:', err);
        return res.status(500).json({ error: 'Failed to update order status' });
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
        return res.status(500).json({ error: 'Failed to list roles' });
    }
});
app.get('/users/:id/role', authenticate, authorize(['admin']), async (req, res) => {
    const uid = req.params.id;
    try {
        const doc = await db.collection('users').doc(uid).get();
        const role = doc.exists ? doc.data().role || null : null;
        return res.json({ uid, role });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to get user role' });
    }
});
app.put('/users/:id/role', authenticate, authorize(['admin']), async (req, res) => {
    const uid = req.params.id;
    const { role } = req.body || {};
    if (!role) return res.status(400).json({ error: 'role is required' });
    try {
        await db.collection('users').doc(uid).set({ role }, { merge: true });
        await admin.auth().setCustomUserClaims(uid, { role });
        return res.json({ uid, role });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to set role' });
    }
});

// Fix orders without dates - sets dates based on status
app.post('/admin/fix-order-dates', authenticate, authorize(['admin']), async (req, res) => {
    try {
        const ordersSnapshot = await db.collection('orders').get();
        let fixed = 0;
        const fixedOrders = [];

        const now = new Date();
        const thirtyFiveDaysAgo = new Date(now.getTime() - 35 * 24 * 60 * 60 * 1000);
        const twentyFiveDaysAgo = new Date(now.getTime() - 25 * 24 * 60 * 60 * 1000);

        for (const doc of ordersSnapshot.docs) {
            const data = doc.data();

            // Skip orders that already have dates
            if (data.created_at || data.date) continue;

            // Determine date based on status
            const status = (data.status || '').toLowerCase();
            let newDate;

            if (status === 'delivered') {
                newDate = twentyFiveDaysAgo;
            } else {
                // processing, in_transit, or any other status
                newDate = thirtyFiveDaysAgo;
            }

            await doc.ref.update({
                created_at: newDate,
                date: newDate.toISOString()
            });

            fixed++;
            fixedOrders.push({
                order_id: doc.id,
                status: status,
                new_date: newDate.toISOString()
            });
        }

        return res.json({ success: true, fixed, fixedOrders });
    } catch (err) {
        console.error('Fix order dates error:', err);
        return res.status(500).json({ error: 'Failed to fix order dates', details: err.message });
    }
});

// Backfill user_id for refunds missing it
app.post('/admin/fix-refund-user-ids', authenticate, authorize(['admin']), async (req, res) => {
    try {
        const refundsSnapshot = await db.collection('refunds').get();
        let fixed = 0;
        const fixedRefunds = [];

        for (const doc of refundsSnapshot.docs) {
            const refundData = doc.data();

            // Skip if already has user_id
            if (refundData.user_id) continue;

            // Look up the order to get user_id
            const orderId = refundData.order_id;
            if (!orderId) continue;

            const orderDoc = await db.collection('orders').doc(String(orderId)).get();
            if (!orderDoc.exists) continue;

            const orderData = orderDoc.data();
            const userId = orderData.user_id;

            if (userId) {
                // Also get customer info for completeness
                let customerName = '';
                let customerEmail = '';
                try {
                    const userDoc = await db.collection('users').doc(String(userId)).get();
                    if (userDoc.exists) {
                        customerName = userDoc.data().name || '';
                        customerEmail = userDoc.data().email || '';
                    }
                } catch (e) {}

                await doc.ref.update({
                    user_id: userId,
                    customer_name: customerName || refundData.customer_name || '',
                    customer_email: customerEmail || refundData.customer_email || ''
                });
                fixed++;
                fixedRefunds.push({
                    refund_id: doc.id,
                    order_id: orderId,
                    user_id: userId
                });
            }
        }

        return res.json({ success: true, fixed, fixedRefunds });
    } catch (err) {
        console.error('Fix refund user IDs error:', err);
        return res.status(500).json({ error: 'Failed to fix refund user IDs', details: err.message });
    }
});

app.get('/users/:uid/orders', authenticate, async (req, res) => {
    const uid = req.params.uid;
    if (String(req.user.uid) !== String(uid) && req.user.role !== 'admin') {
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
            snapshotOrdered = false;
            ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', uidQuery)
                .get();
        }

        // Get user's current address for backfilling missing addresses
        let userCurrentAddress = 'N/A';
        try {
            const userDoc = await db.collection('users').doc(String(uidQuery)).get();
            if (userDoc.exists) {
                userCurrentAddress = userDoc.data().address || 'N/A';
            }
        } catch (err) {
            console.error('Error fetching user address:', err);
        }

        const orders = [];
        for (const orderDoc of ordersSnapshot.docs) {
            const orderData = orderDoc.data();
            const orderId = orderData.order_id;
            
            // Get delivery_address without updating the order (to prevent unintended side effects)
            let deliveryAddress = orderData.delivery_address || orderData.deliveryAddress || userCurrentAddress;

            let items = [];
            if (Array.isArray(orderData.items) && orderData.items.length) {
                items = orderData.items;
            } else {
                const itemsSnapshot = await db.collection('order_items').where('order_id', '==', orderId).get();
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
                        } else {
                            console.log(`Product doc ${productId} not found`);
                        }
                    } catch (e) {
                        console.error(`Error fetching product ${productId}:`, e.message);
                    }
                }
                
                // Check if there's a refund for this item
                let refundStatus = null;
                try {
                    const refundSnapshot = await db.collection('refunds')
                        .where('order_id', '==', orderId)
                        .where('product_id', '==', productId)
                        .limit(1)
                        .get();
                    
                    if (!refundSnapshot.empty) {
                        const refundData = refundSnapshot.docs[0].data();
                        refundStatus = refundData.status; // 'requested', 'refunded', 'rejected'
                    }
                } catch (e) {
                    // Ignore refund lookup errors
                }
                
                enrichedItems.push({
                    ...productDetails,
                    ...item,
                    name: item.name || productDetails.name || 'Unknown Product',
                    image_url: productDetails.image_url || item.image_url || item.imageUrl || null,
                    refund_status: refundStatus || item.refund_status || null
                });
            }

            // Safely extract created_at timestamp - never use current date as fallback to prevent date changes
            let createdAt;
            if (orderData.created_at && typeof orderData.created_at.toDate === 'function') {
                createdAt = orderData.created_at.toDate().toISOString();
            } else if (orderData.date) {
                // If date exists, try to parse it
                if (typeof orderData.date.toDate === 'function') {
                    createdAt = orderData.date.toDate().toISOString();
                } else if (typeof orderData.date === 'string') {
                    createdAt = orderData.date;
                } else {
                    // Keep original date value as-is, don't replace with current time
                    createdAt = orderData.date.toString();
                }
            } else {
                // Use fixed historical date for orders without dates (prevents dates from changing)
                createdAt = '2023-01-01T00:00:00.000Z';
            }
            orders.push({
                ...orderData,
                items: enrichedItems,
                date: createdAt,
                created_at: createdAt, // Also include created_at for frontend
                delivery_address: deliveryAddress // Ensure delivery_address is included
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

app.get('/users/:uid/products/:productId/eligibility', authenticate, async (req, res) => {
    const { uid, productId } = req.params;
    if (String(req.user.uid) !== String(uid) && req.user.role !== 'admin' && req.user.role !== 'product_manager') {
        return res.status(403).json({ error: "Unauthorized" });
    }

    const uidQuery = /^\d+$/.test(uid) ? parseInt(uid) : uid;
    const pidString = String(productId);
    const pidNumber = /^\d+$/.test(pidString) ? parseInt(pidString) : null;

    console.log(`[Eligibility Check] User: ${uid} (${uidQuery}), Product: ${productId} (string: ${pidString}, number: ${pidNumber})`);

    try {
        const ordersSnapshot = await db.collection('orders')
            .where('user_id', '==', uidQuery)
            .where('status', '==', 'delivered')
            .get();
        console.log(`[Eligibility Check] Found ${ordersSnapshot.size} delivered orders for user ${uidQuery}`);

        if (ordersSnapshot.empty) {
            console.log(`[Eligibility Check] No delivered orders found for user ${uidQuery}`);
            return res.json({ canReview: false });
        }

        let canReview = false;
        for (const orderDoc of ordersSnapshot.docs) {
            const orderData = orderDoc.data();
            const orderId = orderData.order_id;
            const orderStatus = orderData.status;

            console.log(`[Eligibility Check] Checking order ${orderId} with status: ${orderStatus}`);
            const orderItems = orderData.items;
            console.log(`[Eligibility Check] Order ${orderId} has ${Array.isArray(orderItems) ? orderItems.length : 0} items`);
            if (Array.isArray(orderItems) && orderItems.length > 0) {
                const found = orderItems.some(i => {
                    const itemPid = i.product_id;
                    const itemPidStr = String(itemPid);
                    const itemPidNum = Number(itemPid);

                    const matches = String(itemPid) === pidString ||
                        (pidNumber !== null && Number(itemPid) === pidNumber) ||
                        itemPid == pidString ||
                        (pidNumber !== null && itemPid == pidNumber);

                    if (matches) {
                        console.log(`[Eligibility Check] Match found! Order ${orderId}, item product_id: ${itemPid} (type: ${typeof itemPid}) matches ${productId}`);
                    }

                    return matches;
                });
                if (found) {
                    canReview = true;
                    console.log(`[Eligibility Check] User CAN review - found product in order ${orderId}`);
                    break;
                } else {
                    console.log(`[Eligibility Check] Order ${orderId} items:`, orderItems.map(i => ({ pid: i.product_id, type: typeof i.product_id })));
                }
            } else {
                let itemSnapshot = null;
                if (pidNumber !== null) {
                    itemSnapshot = await db.collection('order_items')
                        .where('order_id', '==', orderId)
                        .where('product_id', '==', pidNumber)
                        .limit(1)
                        .get();
                }
                if ((!itemSnapshot || itemSnapshot.empty) && (pidNumber === null || pidString !== String(pidNumber))) {
                    itemSnapshot = await db.collection('order_items')
                        .where('order_id', '==', orderId)
                        .where('product_id', '==', pidString)
                        .limit(1)
                        .get();
                }
                if (itemSnapshot && !itemSnapshot.empty) {
                    canReview = true;
                    console.log(`[Eligibility Check] User CAN review - found product in order_items for order ${orderId}`);
                    break;
                }
            }
        }

        console.log(`[Eligibility Check] Final result: canReview = ${canReview}`);
        return res.json({ canReview });
    } catch (err) {
        console.error("Eligibility check error:", err);
        return res.status(500).json({ error: err.message });
    }
});

// Batch eligibility check endpoint - checks multiple user-product pairs at once
app.post('/reviews/moderation/eligibility-batch', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    const { checks } = req.body; // Array of {user_id, product_id}
    
    if (!Array.isArray(checks) || checks.length === 0) {
        return res.status(400).json({ error: 'Invalid request. Expected array of {user_id, product_id}' });
    }

    try {
        const results = {};
        
        // Group checks by user_id to minimize database queries
        const userGroups = {};
        for (const check of checks) {
            const userId = String(check.user_id);
            if (!userGroups[userId]) {
                userGroups[userId] = [];
            }
            userGroups[userId].push(check);
        }

        // Process all user groups in PARALLEL for maximum speed
        const userPromises = Object.entries(userGroups).map(async ([userId, userChecks]) => {
            const uidQuery = /^\d+$/.test(userId) ? parseInt(userId) : userId;
            
            // Get all delivered orders for this user (single query per user)
            const ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', uidQuery)
                .where('status', '==', 'delivered')
                .get();

            // Build a set of product IDs this user has in delivered orders
            const userProductSet = new Set();
            const orderIdsForItems = [];
            
            for (const orderDoc of ordersSnapshot.docs) {
                const orderData = orderDoc.data();
                const orderItems = orderData.items;
                
                if (Array.isArray(orderItems) && orderItems.length > 0) {
                    // Items are in the order document itself
                    for (const item of orderItems) {
                        const pid = item.product_id;
                        userProductSet.add(String(pid));
                        if (/^\d+$/.test(String(pid))) {
                            userProductSet.add(Number(pid).toString());
                        }
                    }
                } else {
                    // Need to check order_items collection - collect order IDs
                    const orderId = orderData.order_id;
                    if (orderId) {
                        orderIdsForItems.push(orderId);
                    }
                }
            }

            // OPTIMIZATION: Batch fetch all order_items in one query instead of N queries
            if (orderIdsForItems.length > 0) {
                // Firestore whereIn limit is 10, so we need to batch
                const batchSize = 10;
                for (let i = 0; i < orderIdsForItems.length; i += batchSize) {
                    const batch = orderIdsForItems.slice(i, i + batchSize);
                    const itemSnapshot = await db.collection('order_items')
                        .where('order_id', 'in', batch)
                        .get();
                    
                    for (const itemDoc of itemSnapshot.docs) {
                        const pid = itemDoc.data().product_id;
                        userProductSet.add(String(pid));
                        if (/^\d+$/.test(String(pid))) {
                            userProductSet.add(Number(pid).toString());
                        }
                    }
                }
            }

            // Check eligibility for each product for this user
            const userResults = {};
            for (const check of userChecks) {
                const productId = String(check.product_id);
                const key = `${check.user_id}-${check.product_id}`;
                
                // Check if product exists in user's delivered orders
                const canReview = userProductSet.has(productId) || 
                                 userProductSet.has(Number(productId).toString()) ||
                                 (/^\d+$/.test(productId) && userProductSet.has(parseInt(productId).toString()));
                
                userResults[key] = canReview;
            }
            
            return userResults;
        });

        // Wait for all users to be processed in parallel
        const allUserResults = await Promise.all(userPromises);
        
        // Merge all results
        for (const userResult of allUserResults) {
            Object.assign(results, userResult);
        }

        return res.json({ eligibilities: results });
    } catch (err) {
        console.error("Batch eligibility check error:", err);
        return res.status(500).json({ error: err.message });
    }
});

// Batch product details endpoint - fetch multiple products at once
app.post('/products/batch', async (req, res) => {
    const { product_ids } = req.body;
    
    if (!Array.isArray(product_ids) || product_ids.length === 0) {
        return res.status(400).json({ error: 'Invalid request. Expected array of product_ids' });
    }

    try {
        const products = {};
        
        // Firestore whereIn limit is 10, so we need to batch
        const batchSize = 10;
        const productPromises = [];
        
        for (let i = 0; i < product_ids.length; i += batchSize) {
            const batch = product_ids.slice(i, i + batchSize).map(id => String(id));
            const promise = Promise.all(batch.map(async (productId) => {
                try {
                    // Try to get by document ID first
                    const doc = await db.collection('products').doc(productId).get();
                    if (doc.exists) {
                        const data = doc.data();
                        const pid = data.product_id ?? productId;
                        return { id: String(pid), data: { ...data, product_id: pid } };
                    }
                    
                    // If not found by doc ID, try querying by product_id field
                    const querySnapshot = await db.collection('products')
                        .where('product_id', '==', /^\d+$/.test(productId) ? parseInt(productId) : productId)
                        .limit(1)
                        .get();
                    
                    if (!querySnapshot.empty) {
                        const data = querySnapshot.docs[0].data();
                        const pid = data.product_id ?? productId;
                        return { id: String(pid), data: { ...data, product_id: pid } };
                    }
                    
                    return null;
                } catch (e) {
                    console.error(`Error fetching product ${productId}:`, e);
                    return null;
                }
            })).then(results => {
                results.forEach(result => {
                    if (result) {
                        products[result.id] = result.data;
                    }
                });
            });
            productPromises.push(promise);
        }
        
        await Promise.all(productPromises);
        
        return res.json({ products });
    } catch (err) {
        console.error("Batch product details error:", err);
        return res.status(500).json({ error: err.message });
    }
});

app.get('/products/:id/reviews', async (req, res) => {
    const productId = req.params.id;
    const pidInt = parseInt(productId);
    const pidQuery = isNaN(pidInt) ? productId : pidInt;

    try {
        const snapshot = await db.collection('reviews')
            .where('product_id', '==', pidQuery)
            .where('approval_status', '==', 'approved')
            .get();

        const reviews = [];
        snapshot.forEach(doc => reviews.push(doc.data()));

        const withTime = [];
        const noTime = [];

        reviews.forEach(r => {
            if (r.timestamp) {
                withTime.push(r);
            } else {
                noTime.push(r);
            }
        });

        withTime.sort((a, b) => {

            const dateA = new Date(a.timestamp).getTime();
            const dateB = new Date(b.timestamp).getTime();
            return dateB - dateA;
        });
        noTime.sort((a, b) => {
            const commentA = (a.comment || "").trim();
            const commentB = (b.comment || "").trim();

            if (commentA.length !== commentB.length) {
                return commentA.length - commentB.length;
            }

            const nameA = (a.author_name || "").toLowerCase();
            const nameB = (b.author_name || "").toLowerCase();
            if (nameA < nameB) return -1;
            if (nameA > nameB) return 1;
            return 0;
        });
        const finalReviews = [...withTime, ...noTime];

        return res.json({ reviews: finalReviews });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: err.message });
    }
});
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
app.post('/reviews', authenticate, async (req, res) => {
    const { product_id, rating, comment } = req.body;

    if (!product_id || !rating) {
        return res.status(400).json({ error: "Missing product_id or rating" });
    }

    const userId = req.user.uid;
    const pidInt = parseInt(product_id);
    const finalProductId = isNaN(pidInt) ? product_id : pidInt;

    try {
        const userDoc = await db.collection('users').doc(String(userId)).get();
        const userName = userDoc.exists ? (userDoc.data().name || "Customer") : "Customer";

        const cleanComment = comment ? comment.trim() : "";

        let approvalStatus = 'pending';
        if (cleanComment.length === 0) {
            approvalStatus = 'approved';
        }

        const newReview = {
            review_id: Date.now().toString() + Math.floor(Math.random() * 1000),
            user_id: userId,
            author_name: userName,
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

app.get('/reviews/moderation', authenticate, authorize(['product_manager']), async (req, res) => {
    try {
        const snapshot = await db.collection('reviews').where('approval_status', '==', 'pending').get();
        const reviews = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.json({ reviews });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to load pending reviews' });
    }
});
app.put('/reviews/:id/approve', authenticate, authorize(['product_manager']), async (req, res) => {
    const reviewId = req.params.id;
    const { decision, reason } = req.body || {};
    const normalizedDecision = (decision || 'approved').toLowerCase();

    if (!['approved', 'rejected'].includes(normalizedDecision)) {
        return res.status(400).json({ error: 'Invalid decision' });
    }

    try {
        const reviewRef = db.collection('reviews').doc(reviewId);
        const reviewDoc = await reviewRef.get();
        if (!reviewDoc.exists) return res.status(404).json({ error: 'Review not found' });

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
        return res.status(500).json({ error: 'Failed to update review approval' });
    }
});

app.delete('/reviews/:id', authenticate, async (req, res) => {
    const reviewId = req.params.id;
    try {
        const docRef = db.collection('reviews').doc(reviewId);
        const doc = await docRef.get();
        if (!doc.exists) return res.status(404).json({ error: "Review not found" });
        if (String(doc.data().user_id) !== String(req.user.uid)) return res.status(403).json({ error: "Unauthorized" });

        await docRef.delete();
        return res.json({ success: true });
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});
app.post('/users/:uid/cart', authenticate, async (req, res) => {
    const uid = req.params.uid;
    const { items } = req.body;
    if (String(req.user.uid) !== String(uid)) return res.status(403).json({ error: 'Unauthorized' });
    try {
        await db.collection('users').doc(uid).set({ saved_cart: items || [] }, { merge: true });
        return res.json({ success: true, message: 'Cart saved successfully' });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to save cart' });
    }
});

app.get('/users/:uid/cart', authenticate, async (req, res) => {
    const uid = req.params.uid;
    if (String(req.user.uid) !== String(uid)) return res.status(403).json({ error: 'Unauthorized' });
    try {
        const userDoc = await db.collection('users').doc(uid).get();
        if (!userDoc.exists) return res.json({ cart: [] });
        const cart = userDoc.data().saved_cart || [];
        return res.json({ cart });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to get cart' });
    }
});

app.post('/logout', authenticate, async (req, res) => {
    const { cart } = req.body;
    const uid = req.user.uid;
    try {
        if (cart && Array.isArray(cart)) {
            await db.collection('users').doc(String(uid)).set({ saved_cart: cart }, { merge: true });
        }
        return res.json({ success: true, message: 'Logged out' });
    } catch (err) {
        return res.status(500).json({ error: 'Failed to logout' });
    }
});
// ============================================
// REFUND ENDPOINTS
// ============================================

// POST /refunds/request - Customer requests refund
app.post('/refunds/request', authenticate, async (req, res) => {
    try {
        const { order_id, product_id, reason } = req.body;
        const userId = req.user.uid || req.user.user_id;

        if (!order_id || !product_id) {
            return res.status(400).json({ error: 'order_id and product_id are required' });
        }

        // Get order details
        const orderRef = db.collection('orders').doc(String(order_id));
        const orderDoc = await orderRef.get();

        if (!orderDoc.exists) {
            return res.status(404).json({ error: 'Order not found' });
        }

        const orderData = orderDoc.data();
        const orderUserId = orderData.user_id;
        
        // Verify order belongs to user
        if (String(orderUserId) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized - order does not belong to user' });
        }

        // Check order status is delivered
        if (orderData.status !== 'delivered') {
            return res.status(400).json({ error: 'Refund can only be requested for delivered orders' });
        }

        // Check 30-day window from PURCHASE DATE (not delivery date)
        const purchaseDate = orderData.created_at 
            ? (orderData.created_at.toDate ? orderData.created_at.toDate() : new Date(orderData.created_at))
            : (orderData.date ? new Date(orderData.date) : new Date());
        
        const daysSincePurchase = (Date.now() - purchaseDate.getTime()) / (1000 * 60 * 60 * 24);
        if (daysSincePurchase > 30) {
            return res.status(400).json({ error: 'Refund can only be requested within 30 days of purchase' });
        }

        // Find the product in order items
        const items = orderData.items || [];
        const orderItem = items.find(item => 
            String(item.product_id) === String(product_id)
        );

        if (!orderItem) {
            return res.status(404).json({ error: 'Product not found in this order' });
        }

        // Check if refund already exists for this order+product
        const existingRefunds = await db.collection('refunds')
            .where('order_id', '==', Number(order_id))
            .where('product_id', '==', Number(product_id))
            .where('status', 'in', ['requested', 'approved'])
            .get();

        if (!existingRefunds.empty) {
            return res.status(400).json({ error: 'Refund already requested for this product' });
        }

        // Get next refund ID
        const countersRef = db.collection('meta').doc('counters');
        let refundId = 1;
        await db.runTransaction(async (tx) => {
            const snap = await tx.get(countersRef);
            if (snap.exists && typeof snap.data().nextRefundId === 'number') {
                refundId = snap.data().nextRefundId;
                tx.update(countersRef, { nextRefundId: refundId + 1 });
            } else {
                refundId = 1;
                tx.set(countersRef, { nextRefundId: 2 }, { merge: true });
            }
        });

        // Get user info for refund document
        let customerName = '';
        let customerEmail = '';
        try {
            const userDoc = await db.collection('users').doc(String(userId)).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                customerName = userData.name || '';
                customerEmail = userData.email || '';
            }
        } catch (err) {
            console.error('Error fetching user info for refund:', err);
        }

        // Create refund request
        // Store the original unit_price to preserve purchase-time discount
        const refundData = {
            refund_id: refundId,
            order_id: Number(order_id),
            product_id: Number(product_id),
            user_id: userId,
            customer_name: customerName, // Store customer name
            customer_email: customerEmail, // Store customer email
            quantity: orderItem.quantity || 1,
            unit_price: orderItem.unit_price || 0, // Original price paid (with discount)
            total_refund_amount: (orderItem.unit_price || 0) * (orderItem.quantity || 1),
            reason: reason || '',
            status: 'requested',
            requested_at: FieldValue.serverTimestamp(),
            purchase_date: purchaseDate.toISOString(),
            days_since_purchase: Math.floor(daysSincePurchase)
        };

        await db.collection('refunds').doc(String(refundId)).set(refundData);

        return res.status(201).json({
            success: true,
            message: 'Refund request submitted',
            refund: refundData
        });
    } catch (err) {
        console.error('Refund request error:', err);
        return res.status(500).json({ error: 'Failed to process refund request', details: err.message });
    }
});

// GET /refunds/count - Get count of all refunds (for checking existing refunds)
app.get('/refunds/count', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const snapshot = await db.collection('refunds').get();
        return res.json({ 
            total_count: snapshot.size,
            by_status: {
                requested: snapshot.docs.filter(d => d.data().status === 'requested').length,
                refunded: snapshot.docs.filter(d => d.data().status === 'refunded').length,
                rejected: snapshot.docs.filter(d => d.data().status === 'rejected').length
            }
        });
    } catch (err) {
        console.error('Get refunds count error:', err);
        return res.status(500).json({ error: 'Failed to get refunds count' });
    }
});

// GET /refunds - Sales manager views all refund requests
app.get('/refunds', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { status } = req.query;
        let query = db.collection('refunds');

        if (status) {
            query = query.where('status', '==', status);
        }

        // Note: If using orderBy with where, Firestore requires a composite index
        // For now, we'll fetch all and sort in memory if needed
        let snapshot;
        try {
            snapshot = await query.orderBy('requested_at', 'desc').get();
        } catch (e) {
            // If index doesn't exist, fetch without orderBy and sort in memory
            snapshot = await query.get();
        }
        let refunds = [];

        for (const doc of snapshot.docs) {
            const refundData = doc.data();
            
            // Enrich with product and order details
            try {
                const productDoc = await db.collection('products').doc(String(refundData.product_id)).get();
                const orderDoc = await db.collection('orders').doc(String(refundData.order_id)).get();
                const userDoc = await db.collection('users').doc(String(refundData.user_id)).get();

                refunds.push({
                    id: doc.id,
                    ...refundData,
                    product: productDoc.exists ? productDoc.data() : null,
                    order: orderDoc.exists ? orderDoc.data() : null,
                    user: userDoc.exists ? {
                        name: userDoc.data().name,
                        email: userDoc.data().email,
                        address: userDoc.data().address
                    } : null,
                    requested_at: (() => {
                        try {
                            if (refundData.requested_at && typeof refundData.requested_at.toDate === 'function') {
                                return refundData.requested_at.toDate().toISOString();
                            } else if (refundData.requested_at) {
                                const dateStr = refundData.requested_at.toString();
                                if (dateStr && !dateStr.includes('T')) {
                                    const date = new Date(dateStr);
                                    if (!isNaN(date.getTime())) {
                                        const now = new Date();
                                        date.setHours(now.getHours());
                                        date.setMinutes(now.getMinutes());
                                        date.setSeconds(now.getSeconds());
                                        return date.toISOString();
                                    }
                                }
                                return dateStr;
                            }
                            return new Date().toISOString();
                        } catch (e) {
                            return new Date().toISOString();
                        }
                    })(),
                    approved_at: (() => {
                        try {
                            if (refundData.approved_at && typeof refundData.approved_at.toDate === 'function') {
                                return refundData.approved_at.toDate().toISOString();
                            } else if (refundData.approved_at) {
                                const dateStr = refundData.approved_at.toString();
                                if (dateStr && !dateStr.includes('T')) {
                                    const date = new Date(dateStr);
                                    if (!isNaN(date.getTime())) {
                                        const now = new Date();
                                        date.setHours(now.getHours());
                                        date.setMinutes(now.getMinutes());
                                        date.setSeconds(now.getSeconds());
                                        return date.toISOString();
                                    }
                                }
                                return dateStr;
                            }
                            return null;
                        } catch (e) {
                            return null;
                        }
                    })()
                });
            } catch (e) {
                console.error(`Error enriching refund ${doc.id}:`, e);
                // Fallback: add refund with minimal data
                let requestedAtStr;
                try {
                    if (refundData.requested_at && typeof refundData.requested_at.toDate === 'function') {
                        requestedAtStr = refundData.requested_at.toDate().toISOString();
                    } else {
                        requestedAtStr = refundData.requested_at?.toString() || new Date().toISOString();
                    }
                } catch (e2) {
                    requestedAtStr = new Date().toISOString();
                }

                refunds.push({
                    id: doc.id,
                    refund_id: refundData.refund_id || doc.id,
                    order_id: refundData.order_id || 'N/A',
                    product_id: refundData.product_id || 'N/A',
                    user_id: refundData.user_id || 'N/A',
                    quantity: refundData.quantity || 1,
                    unit_price: refundData.unit_price || 0,
                    total_refund_amount: refundData.total_refund_amount || 0,
                    reason: refundData.reason || '',
                    status: refundData.status || 'requested',
                    requested_at: requestedAtStr,
                    approved_at: null,
                    product: null,
                    order: null,
                    user: { name: 'Unknown', email: 'N/A', address: 'N/A' }
                });
            }
        }

        // Sort by requested_at (date and hour) from newest to oldest
        // Every refund should have a requested_at field
        refunds.sort((a, b) => {
            let dateA = 0;
            let dateB = 0;
            
            // Use requested_at for sorting (required field)
            if (a.requested_at) {
                try {
                    const date = new Date(a.requested_at);
                    if (!isNaN(date.getTime())) {
                        dateA = date.getTime();
                    }
                } catch (e) {
                    console.error(`Error parsing requested_at for refund ${a.id}:`, e);
                    dateA = 0;
                }
            }
            
            if (b.requested_at) {
                try {
                    const date = new Date(b.requested_at);
                    if (!isNaN(date.getTime())) {
                        dateB = date.getTime();
                    }
                } catch (e) {
                    console.error(`Error parsing requested_at for refund ${b.id}:`, e);
                    dateB = 0;
                }
            }
            
            // Descending order: newest first (larger timestamp comes first)
            return dateB - dateA;
        });

        return res.json({ refunds });
    } catch (err) {
        console.error('Get refunds error:', err);
        return res.status(500).json({ error: 'Failed to fetch refunds' });
    }
});

// PUT /refunds/:id/approve - Sales manager approves refund
app.put('/refunds/:id/approve', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        const { decision, reason } = req.body;
        const decisionNormalized = (decision || 'approved').toLowerCase();

        if (!['approved', 'rejected'].includes(decisionNormalized)) {
            return res.status(400).json({ error: 'Invalid decision. Must be "approved" or "rejected"' });
        }

        const refundRef = db.collection('refunds').doc(id);
        const refundDoc = await refundRef.get();

        if (!refundDoc.exists) {
            return res.status(404).json({ error: 'Refund not found' });
        }

        const refundData = refundDoc.data();

        if (refundData.status !== 'requested') {
            return res.status(400).json({ error: `Refund is already ${refundData.status}` });
        }

        // Validate required fields
        if (!refundData.order_id) {
            return res.status(400).json({ error: 'Refund is missing order_id' });
        }

        if (!refundData.product_id) {
            return res.status(400).json({ error: 'Refund is missing product_id' });
        }

        // Verify order exists and contains the product
        const orderRef = db.collection('orders').doc(String(refundData.order_id));
        const orderDocCheck = await orderRef.get();
        
        if (!orderDocCheck.exists) {
            return res.status(404).json({ error: `Order ${refundData.order_id} does not exist` });
        }

        const orderDataCheck = orderDocCheck.data();
        const items = orderDataCheck.items || [];
        const productInOrder = items.find(item => 
            String(item.product_id) === String(refundData.product_id)
        );

        if (!productInOrder) {
            return res.status(400).json({ 
                error: `Product ${refundData.product_id} is not in order ${refundData.order_id}` 
            });
        }

        // Ensure required fields have defaults
        const refundQuantity = refundData.quantity || productInOrder.quantity || 1;
        const calculatedRefundAmount = refundData.total_refund_amount || (productInOrder.unit_price * refundQuantity);

        // Use transaction for atomic operations
        // IMPORTANT: All reads must happen before all writes in Firestore transactions
        await db.runTransaction(async (tx) => {
            // Read all documents first
            const productRef = db.collection('products').doc(String(refundData.product_id));
            const productDoc = await tx.get(productRef);
            const refundDocInTx = await tx.get(refundRef);
            const orderDoc = await tx.get(orderRef);

            // Validate reads
            if (!refundDocInTx.exists) {
                throw new Error('Refund not found in transaction');
            }

            if (!orderDoc.exists) {
                throw new Error(`Order ${refundData.order_id} does not exist`);
            }

            const orderData = orderDoc.data();
            const items = orderData.items || [];
            const productInOrderTx = items.find(item => 
                String(item.product_id) === String(refundData.product_id)
            );

            if (!productInOrderTx) {
                throw new Error(`Product ${refundData.product_id} is not in order ${refundData.order_id}`);
            }

            if (decisionNormalized === 'approved') {
                // Restore product stock
                if (productDoc.exists) {
                    tx.update(productRef, {
                        quantity_in_stock: FieldValue.increment(refundQuantity)
                    });
                } else {
                    throw new Error(`Product ${refundData.product_id} does not exist`);
                }

                // Update refund status
                const refundUpdate = {
                    status: 'refunded',
                    approved_by: req.user.uid || req.user.user_id,
                    approved_at: FieldValue.serverTimestamp(),
                    approval_reason: reason || null
                };
                
                // Update amount if it was missing
                if (!refundData.total_refund_amount || refundData.total_refund_amount === 0) {
                    refundUpdate.total_refund_amount = calculatedRefundAmount;
                    refundUpdate.unit_price = productInOrderTx.unit_price;
                    refundUpdate.quantity = refundQuantity;
                }
                
                tx.update(refundRef, refundUpdate);

                // Update order status to show refund was accepted
                const updatedItems = items.map(item => {
                    if (String(item.product_id) === String(refundData.product_id)) {
                        return { ...item, refund_status: 'refunded' };
                    }
                    return item;
                });
                tx.update(orderRef, {
                    items: updatedItems,
                    refund_status: 'refunded',
                    updated_at: FieldValue.serverTimestamp()
                });
            } else {
                // Rejected
                tx.update(refundRef, {
                    status: 'rejected',
                    approved_by: req.user.uid || req.user.user_id,
                    approved_at: FieldValue.serverTimestamp(),
                    approval_reason: reason || null
                });

                // Update order to show refund was rejected
                const updatedItems = items.map(item => {
                    if (String(item.product_id) === String(refundData.product_id)) {
                        return { ...item, refund_status: 'rejected' };
                    }
                    return item;
                });
                tx.update(orderRef, {
                    items: updatedItems,
                    refund_status: 'rejected',
                    updated_at: FieldValue.serverTimestamp()
                });
            }
        });

        // Send email and in-app notification for refund decision
        try {
            const updatedRefundData = await refundRef.get();
            const finalRefundData = updatedRefundData.data();

            const userId = finalRefundData.user_id || refundData.user_id;
            if (!userId) {
                console.error('Cannot send refund notification: missing user_id');
            } else {
                const userDoc = await db.collection('users').doc(String(userId)).get();
                const userEmail = userDoc.exists ? userDoc.data().email : null;
                const userName = userDoc.exists ? userDoc.data().name : 'Customer';

                const productDoc = await db.collection('products').doc(String(refundData.product_id)).get();
                const productName = productDoc.exists ? productDoc.data().name : 'Product';

                const refundAmount = finalRefundData.total_refund_amount || calculatedRefundAmount || 0;
                const refundQty = finalRefundData.quantity || refundQuantity || 1;

                if (decisionNormalized === 'approved') {
                    // Send approval email with professional template
                    if (userEmail && emailTransporter) {
                        const mailOptions = {
                            from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
                            to: userEmail,
                            subject: `Refund Approved - Order #${refundData.order_id}`,
                            html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:'Helvetica Neue',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.05);">
          <tr>
            <td style="background-color:#FF7733;padding:30px 40px;text-align:center;">
              <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:300;letter-spacing:2px;">CS308 SHOP</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 40px 20px;text-align:center;">
              <div style="width:70px;height:70px;background-color:#E8F5E9;border-radius:50%;margin:0 auto;display:flex;align-items:center;justify-content:center;">
                <span style="color:#4CAF50;font-size:36px;line-height:70px;">&#10003;</span>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 40px 40px;">
              <h2 style="color:#1a1a2e;margin:0 0 24px;font-size:24px;text-align:center;font-weight:400;">Refund Approved</h2>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 16px;">Dear ${userName},</p>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 30px;">Great news! Your refund request has been approved and processed successfully.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8f9fa;border-radius:8px;margin-bottom:30px;">
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Product</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${productName}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Order ID</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">#${refundData.order_id}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Quantity</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${refundQty}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Refund Amount</span><br>
                    <strong style="color:#4CAF50;font-size:22px;">$${refundAmount.toFixed(2)}</strong>
                  </td>
                </tr>
              </table>
              ${reason ? `<p style="color:#6b7280;font-size:14px;line-height:1.6;margin:0 0 20px;padding:16px;background-color:#fff8f0;border-left:3px solid #FF7733;border-radius:4px;"><strong>Note:</strong> ${reason}</p>` : ''}
              <p style="color:#6b7280;font-size:14px;line-height:1.6;margin:0;">The refund will be credited to your original payment method within <strong>5-10 business days</strong>.</p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f8f9fa;padding:24px 40px;text-align:center;border-top:1px solid #e5e7eb;">
              <p style="color:#9ca3af;font-size:12px;margin:0;">Thank you for shopping with us.</p>
              <p style="color:#9ca3af;font-size:12px;margin:8px 0 0;">© 2025 CS308 Shop. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
                            `
                        };
                        await emailTransporter.sendMail(mailOptions);
                        console.log(`Refund approval email sent to ${userEmail}`);
                    }

                    // Create in-app notification for approval
                    // Convert userId to integer if it's a numeric string for consistency
                    const userIdInt = /^\d+$/.test(String(userId)) ? parseInt(userId) : userId;
                    const approvalNotification = {
                        user_id: userIdInt,
                        type: 'refund_approved',
                        title: 'Refund Approved',
                        message: `Your refund for ${productName} ($${refundAmount.toFixed(2)}) has been approved and will be credited to your original payment method.`,
                        refund_id: id,
                        order_id: refundData.order_id,
                        product_name: productName,
                        refund_amount: refundAmount,
                        is_read: false,
                        created_at: FieldValue.serverTimestamp()
                    };
                    await db.collection('notifications').add(approvalNotification);
                    console.log(`Refund approval in-app notification created for user ${userId}`);

                } else {
                    // Send rejection email with professional template
                    if (userEmail && emailTransporter) {
                        const mailOptions = {
                            from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
                            to: userEmail,
                            subject: `Refund Request Update - Order #${refundData.order_id}`,
                            html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:'Helvetica Neue',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.05);">
          <tr>
            <td style="background-color:#FF7733;padding:30px 40px;text-align:center;">
              <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:300;letter-spacing:2px;">CS308 SHOP</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 40px 20px;text-align:center;">
              <div style="width:70px;height:70px;background-color:#FFF3E0;border-radius:50%;margin:0 auto;display:flex;align-items:center;justify-content:center;">
                <span style="color:#FF7733;font-size:36px;line-height:70px;">!</span>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 40px 40px;">
              <h2 style="color:#1a1a2e;margin:0 0 24px;font-size:24px;text-align:center;font-weight:400;">Refund Request Declined</h2>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 16px;">Dear ${userName},</p>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 30px;">We have reviewed your refund request and unfortunately, we are unable to approve it at this time.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8f9fa;border-radius:8px;margin-bottom:30px;">
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Product</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${productName}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Order ID</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">#${refundData.order_id}</strong>
                  </td>
                </tr>
              </table>
              ${reason ? `
              <div style="margin-bottom:30px;padding:20px;background-color:#fff8f0;border-left:3px solid #FF7733;border-radius:4px;">
                <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Reason</span><br>
                <p style="color:#1a1a2e;font-size:14px;line-height:1.6;margin:8px 0 0;">${reason}</p>
              </div>
              ` : ''}
              <p style="color:#6b7280;font-size:14px;line-height:1.6;margin:0 0 20px;">If you believe this decision was made in error or have additional information to provide, please don't hesitate to contact our customer support team.</p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:20px 0;">
                    <a href="mailto:support@cs308shop.com" style="display:inline-block;padding:14px 32px;background-color:#FF7733;color:#ffffff;text-decoration:none;border-radius:6px;font-size:14px;font-weight:500;">Contact Support</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f8f9fa;padding:24px 40px;text-align:center;border-top:1px solid #e5e7eb;">
              <p style="color:#9ca3af;font-size:12px;margin:0;">We appreciate your understanding.</p>
              <p style="color:#9ca3af;font-size:12px;margin:8px 0 0;">© 2025 CS308 Shop. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
                            `
                        };
                        await emailTransporter.sendMail(mailOptions);
                        console.log(`Refund rejection email sent to ${userEmail}`);
                    }

                    // Create in-app notification for rejection
                    // Convert userId to integer if it's a numeric string for consistency
                    const userIdIntRej = /^\d+$/.test(String(userId)) ? parseInt(userId) : userId;
                    const rejectionNotification = {
                        user_id: userIdIntRej,
                        type: 'refund_rejected',
                        title: 'Refund Request Declined',
                        message: `Your refund request for ${productName} was not approved.${reason ? ' Reason: ' + reason : ''}`,
                        refund_id: id,
                        order_id: refundData.order_id,
                        product_name: productName,
                        is_read: false,
                        created_at: FieldValue.serverTimestamp()
                    };
                    await db.collection('notifications').add(rejectionNotification);
                    console.log(`Refund rejection in-app notification created for user ${userId}`);
                }
            }
        } catch (notificationErr) {
            console.error('Refund notification error:', notificationErr);
            // Don't fail the request if notification fails
        }

        const updatedRefund = await refundRef.get();
        return res.json({
            success: true,
            message: `Refund ${decisionNormalized}`,
            refund: updatedRefund.data()
        });
    } catch (err) {
        console.error('Approve refund error:', err);
        console.error('Error stack:', err.stack);
        console.error('Refund data:', JSON.stringify(refundData, null, 2));
        return res.status(500).json({ error: 'Failed to process refund approval', details: err.message });
    }
});

// GET /users/:uid/refunds - Customer views their refund requests
app.get('/users/:uid/refunds', authenticate, async (req, res) => {
    const uid = req.params.uid;
    if (String(req.user.uid) !== String(uid) && req.user.role !== 'admin' && req.user.role !== 'sales_manager') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const snapshot = await db.collection('refunds')
            .where('user_id', '==', uid)
            .orderBy('requested_at', 'desc')
            .get();

        const refunds = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                requested_at: data.requested_at?.toDate?.() 
                    ? data.requested_at.toDate().toISOString()
                    : (data.requested_at || new Date().toISOString()),
                approved_at: data.approved_at?.toDate?.() 
                    ? data.approved_at.toDate().toISOString()
                    : (data.approved_at || null)
            };
        });

        return res.json({ refunds });
    } catch (err) {
        console.error('Get user refunds error:', err);
        // Include error details for index-related errors
        const errorDetails = err.message || err.toString();
        if (errorDetails.includes('index') || errorDetails.includes('FAILED_PRECONDITION')) {
            return res.status(500).json({ 
                error: 'Failed to fetch user refunds',
                details: errorDetails,
                requiresIndex: true,
                indexUrl: err.details || null
            });
        }
        return res.status(500).json({ error: 'Failed to fetch user refunds' });
    }
});

// ============================================
// WISHLIST ENDPOINTS
// ============================================

// GET /users/:uid/wishlist - Get user's wishlist
app.get('/users/:uid/wishlist', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only access their own wishlist
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const userDoc = await db.collection('users').doc(String(uid)).get();
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        const userData = userDoc.data();
        const wishlistProductIds = userData.wishlist || [];
        
        // Fetch product details for wishlist items
        const products = [];
        for (const productId of wishlistProductIds) {
            try {
                const productDoc = await db.collection('products').doc(String(productId)).get();
                if (productDoc.exists) {
                    products.push({
                        id: productDoc.id,
                        ...productDoc.data()
                    });
                }
            } catch (e) {
                console.error(`Error fetching product ${productId}:`, e);
            }
        }
        
        return res.json({ wishlist: products });
    } catch (err) {
        console.error('Get wishlist error:', err);
        return res.status(500).json({ error: 'Failed to fetch wishlist', details: err.message });
    }
});

// POST /users/:uid/wishlist - Add product to wishlist
app.post('/users/:uid/wishlist', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const { product_id } = req.body;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only modify their own wishlist
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        if (!product_id) {
            return res.status(400).json({ error: 'product_id is required' });
        }
        
        const userRef = db.collection('users').doc(String(uid));
        const userDoc = await userRef.get();
        
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        const userData = userDoc.data();
        const wishlist = userData.wishlist || [];
        const productIdStr = String(product_id);
        
        // Check if product already in wishlist
        if (wishlist.includes(productIdStr)) {
            return res.status(400).json({ error: 'Product already in wishlist' });
        }
        
        // Verify product exists
        const productDoc = await db.collection('products').doc(String(product_id)).get();
        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }
        
        // Add to wishlist
        await userRef.update({
            wishlist: FieldValue.arrayUnion(productIdStr)
        });
        
        return res.json({ success: true, message: 'Product added to wishlist' });
    } catch (err) {
        console.error('Add to wishlist error:', err);
        return res.status(500).json({ error: 'Failed to add to wishlist', details: err.message });
    }
});

// DELETE /users/:uid/wishlist/:productId - Remove product from wishlist
app.delete('/users/:uid/wishlist/:productId', authenticate, async (req, res) => {
    try {
        const { uid, productId } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only modify their own wishlist
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const userRef = db.collection('users').doc(String(uid));
        const userDoc = await userRef.get();
        
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        // Remove from wishlist
        await userRef.update({
            wishlist: FieldValue.arrayRemove(String(productId))
        });
        
        return res.json({ success: true, message: 'Product removed from wishlist' });
    } catch (err) {
        console.error('Remove from wishlist error:', err);
        return res.status(500).json({ error: 'Failed to remove from wishlist', details: err.message });
    }
});

// ============================================
// ORDER CANCELLATION ENDPOINTS
// ============================================

// PUT /orders/:orderId/cancel - Customer cancels order (only if processing)
app.put('/orders/:orderId/cancel', authenticate, async (req, res) => {
    try {
        const { orderId } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        const orderRef = db.collection('orders').doc(String(orderId));
        const orderDoc = await orderRef.get();
        
        if (!orderDoc.exists) {
            return res.status(404).json({ error: 'Order not found' });
        }
        
        const orderData = orderDoc.data();
        
        // Verify order belongs to user
        if (String(orderData.user_id) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized - order does not belong to user' });
        }
        
        // Check order status - can only cancel if processing
        if (orderData.status !== 'processing') {
            return res.status(400).json({ 
                error: 'Order can only be cancelled when status is "processing"',
                currentStatus: orderData.status
            });
        }
        
        // Use transaction to restore stock and cancel order
        await db.runTransaction(async (tx) => {
            // Restore stock for each item
            const items = orderData.items || [];
            for (const item of items) {
                const productRef = db.collection('products').doc(String(item.product_id));
                const productDoc = await tx.get(productRef);
                
                if (productDoc.exists) {
                    tx.update(productRef, {
                        quantity_in_stock: FieldValue.increment(item.quantity || 1)
                    });
                }
            }
            
            // Update order status to cancelled
            tx.update(orderRef, {
                status: 'cancelled',
                cancelled_at: FieldValue.serverTimestamp(),
                updated_at: FieldValue.serverTimestamp()
            });
        });
        
        return res.json({ success: true, message: 'Order cancelled successfully' });
    } catch (err) {
        console.error('Cancel order error:', err);
        return res.status(500).json({ error: 'Failed to cancel order', details: err.message });
    }
});

// ============================================
// SALES MANAGER - PRICE & DISCOUNT ENDPOINTS
// ============================================

// GET /products - Get all products (for sales manager)
app.get('/products', async (req, res) => {
    try {
        const snapshot = await db.collection('products').get();
        const products = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));
        return res.json({ products });
    } catch (err) {
        console.error('Get products error:', err);
        return res.status(500).json({ error: 'Failed to fetch products' });
    }
});

// PUT /products/:id/price - Sales manager sets product price (11.1)
app.put('/products/:id/price', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        const { price } = req.body;

        if (price === undefined || price === null) {
            return res.status(400).json({ error: 'price is required' });
        }

        const newPrice = Number(price);
        if (isNaN(newPrice) || newPrice < 0) {
            return res.status(400).json({ error: 'Invalid price value' });
        }

        const productRef = db.collection('products').doc(String(id));
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const oldPrice = productDoc.data().price || 0;

        await productRef.update({
            price: newPrice,
            original_price: productDoc.data().original_price || oldPrice, // Keep original if exists
            price_updated_at: FieldValue.serverTimestamp(),
            price_updated_by: req.user.uid || req.user.user_id
        });

        const updatedDoc = await productRef.get();
        return res.json({
            success: true,
            message: 'Product price updated successfully',
            product: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (err) {
        console.error('Update price error:', err);
        return res.status(500).json({ error: 'Failed to update product price', details: err.message });
    }
});

// PUT /products/:id/discount - Sales manager sets discount (11.2)
// System calculates new price and notifies wishlist users (11.3)
app.put('/products/:id/discount', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        const { discount_rate } = req.body;

        if (discount_rate === undefined || discount_rate === null) {
            return res.status(400).json({ error: 'discount_rate is required (0-100)' });
        }

        const discountRate = Number(discount_rate);
        if (isNaN(discountRate) || discountRate < 0 || discountRate > 100) {
            return res.status(400).json({ error: 'discount_rate must be between 0 and 100' });
        }

        const productRef = db.collection('products').doc(String(id));
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const productData = productDoc.data();
        const originalPrice = productData.original_price || productData.price || 0;
        
        // Calculate new discounted price
        const newPrice = discountRate > 0 
            ? Number((originalPrice * (1 - discountRate / 100)).toFixed(2))
            : originalPrice;

        await productRef.update({
            price: newPrice,
            original_price: originalPrice,
            discount_rate: discountRate,
            discount_updated_at: FieldValue.serverTimestamp(),
            discount_updated_by: req.user.uid || req.user.user_id
        });

        // 11.3 - Create in-app notifications for users whose wishlist includes this discounted product
        let notifiedUsers = [];
        if (discountRate > 0) {
            try {
                // Find users who have this product in their wishlist
                const usersSnapshot = await db.collection('users').get();
                const productIdStr = String(id);
                
                for (const userDoc of usersSnapshot.docs) {
                    const userData = userDoc.data();
                    const wishlist = userData.wishlist || [];
                    
                    // Check if product is in wishlist (check both string and number)
                    const hasInWishlist = wishlist.some(wid => 
                        String(wid) === productIdStr || wid == id
                    );
                    
                    if (hasInWishlist) {
                        // Create in-app notification
                        const notificationData = {
                            user_id: userData.user_id || userDoc.id,
                            type: 'price_drop',
                            title: '🎉 Price Drop Alert!',
                            message: `${productData.name} is now ${discountRate}% off! Was $${originalPrice.toFixed(2)}, now $${newPrice.toFixed(2)}`,
                            product_id: Number(id),
                            product_name: productData.name,
                            original_price: originalPrice,
                            new_price: newPrice,
                            discount_rate: discountRate,
                            is_read: false,
                            created_at: FieldValue.serverTimestamp()
                        };

                        await db.collection('notifications').add(notificationData);
                        notifiedUsers.push(userData.user_id || userDoc.id);
                        console.log(`In-app notification created for user ${userData.user_id || userDoc.id} for product ${id}`);
                    }
                }
            } catch (notifyErr) {
                console.error('Error creating notifications:', notifyErr);
            }
        }

        const updatedDoc = await productRef.get();
        return res.json({
            success: true,
            message: `Discount applied successfully. ${notifiedUsers.length} wishlist user(s) notified.`,
            product: { id: updatedDoc.id, ...updatedDoc.data() },
            notified_users_count: notifiedUsers.length
        });
    } catch (err) {
        console.error('Apply discount error:', err);
        return res.status(500).json({ error: 'Failed to apply discount', details: err.message });
    }
});

// DELETE /products/:id/discount - Remove discount from product
app.delete('/products/:id/discount', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        
        const productRef = db.collection('products').doc(String(id));
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const productData = productDoc.data();
        const originalPrice = productData.original_price || productData.price;

        await productRef.update({
            price: originalPrice,
            discount_rate: 0,
            discount_updated_at: FieldValue.serverTimestamp(),
            discount_updated_by: req.user.uid || req.user.user_id
        });

        const updatedDoc = await productRef.get();
        return res.json({
            success: true,
            message: 'Discount removed successfully',
            product: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (err) {
        console.error('Remove discount error:', err);
        return res.status(500).json({ error: 'Failed to remove discount', details: err.message });
    }
});

// ============================================
// NOTIFICATION ENDPOINTS (11.3 - In-App Notifications)
// ============================================

// GET /users/:uid/notifications - Get user's notifications
app.get('/users/:uid/notifications', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only access their own notifications
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        // Query with both int and string versions of user_id for compatibility
        const uidInt = /^\d+$/.test(uid) ? parseInt(uid) : null;
        const uidStr = String(uid);

        let allDocs = [];

        // Try to fetch with integer user_id
        if (uidInt !== null) {
            try {
                const snapshotInt = await db.collection('notifications')
                    .where('user_id', '==', uidInt)
                    .orderBy('created_at', 'desc')
                    .limit(50)
                    .get();
                allDocs = allDocs.concat(snapshotInt.docs);
            } catch (e) {
                const snapshotInt = await db.collection('notifications')
                    .where('user_id', '==', uidInt)
                    .get();
                allDocs = allDocs.concat(snapshotInt.docs);
            }
        }

        // Also fetch with string user_id (for older notifications)
        try {
            const snapshotStr = await db.collection('notifications')
                .where('user_id', '==', uidStr)
                .orderBy('created_at', 'desc')
                .limit(50)
                .get();
            allDocs = allDocs.concat(snapshotStr.docs);
        } catch (e) {
            const snapshotStr = await db.collection('notifications')
                .where('user_id', '==', uidStr)
                .get();
            allDocs = allDocs.concat(snapshotStr.docs);
        }

        // Deduplicate by doc id
        const seenIds = new Set();
        const uniqueDocs = allDocs.filter(doc => {
            if (seenIds.has(doc.id)) return false;
            seenIds.add(doc.id);
            return true;
        });

        const notifications = uniqueDocs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                created_at: data.created_at?.toDate?.() 
                    ? data.created_at.toDate().toISOString()
                    : (data.created_at || new Date().toISOString())
            };
        });
        
        // Sort by created_at descending if we couldn't use orderBy
        notifications.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        
        return res.json({ notifications });
    } catch (err) {
        console.error('Get notifications error:', err);
        return res.status(500).json({ error: 'Failed to fetch notifications' });
    }
});

// GET /users/:uid/notifications/unread-count - Get unread notification count
app.get('/users/:uid/notifications/unread-count', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        // Query with both int and string versions of user_id for compatibility
        const uidInt = /^\d+$/.test(uid) ? parseInt(uid) : null;
        const uidStr = String(uid);

        let allDocs = [];

        // Fetch with integer user_id
        if (uidInt !== null) {
            const snapshotInt = await db.collection('notifications')
                .where('user_id', '==', uidInt)
                .where('is_read', '==', false)
                .get();
            allDocs = allDocs.concat(snapshotInt.docs);
        }

        // Also fetch with string user_id
        const snapshotStr = await db.collection('notifications')
            .where('user_id', '==', uidStr)
            .where('is_read', '==', false)
            .get();
        allDocs = allDocs.concat(snapshotStr.docs);

        // Deduplicate by doc id
        const seenIds = new Set();
        const uniqueCount = allDocs.filter(doc => {
            if (seenIds.has(doc.id)) return false;
            seenIds.add(doc.id);
            return true;
        }).length;

        return res.json({ count: uniqueCount });
    } catch (err) {
        console.error('Get unread count error:', err);
        return res.status(500).json({ error: 'Failed to get unread count' });
    }
});

// PUT /notifications/:id/read - Mark notification as read
app.put('/notifications/:id/read', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        
        const notificationRef = db.collection('notifications').doc(id);
        const notificationDoc = await notificationRef.get();
        
        if (!notificationDoc.exists) {
            return res.status(404).json({ error: 'Notification not found' });
        }
        
        // Verify ownership
        const notificationData = notificationDoc.data();
        const userId = req.user.uid || req.user.user_id;
        if (String(notificationData.user_id) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        await notificationRef.update({
            is_read: true,
            read_at: FieldValue.serverTimestamp()
        });
        
        return res.json({ success: true, message: 'Notification marked as read' });
    } catch (err) {
        console.error('Mark notification read error:', err);
        return res.status(500).json({ error: 'Failed to mark notification as read' });
    }
});

// PUT /users/:uid/notifications/read-all - Mark all notifications as read
app.put('/users/:uid/notifications/read-all', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const uidQuery = /^\d+$/.test(uid) ? parseInt(uid) : uid;
        
        const snapshot = await db.collection('notifications')
            .where('user_id', '==', uidQuery)
            .where('is_read', '==', false)
            .get();
        
        const batch = db.batch();
        snapshot.docs.forEach(doc => {
            batch.update(doc.ref, { 
                is_read: true, 
                read_at: FieldValue.serverTimestamp() 
            });
        });
        
        await batch.commit();
        
        return res.json({ success: true, message: `${snapshot.size} notifications marked as read` });
    } catch (err) {
        console.error('Mark all read error:', err);
        return res.status(500).json({ error: 'Failed to mark notifications as read' });
    }
});

// POST /test/refund-emails - Send test refund emails (for demonstration)
app.post('/test/refund-emails', async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email address is required' });
        }

        if (!emailTransporter) {
            return res.status(500).json({ error: 'Email transporter not configured. Check EMAIL_USER and EMAIL_PASS in .env' });
        }

        // Mock data for the test emails
        const mockData = {
            userName: 'Valued Customer',
            productName: 'Wireless Headphones',
            orderId: '12345',
            refundQty: 1,
            refundAmount: 149.99,
            reason: 'Product was defective upon arrival'
        };

        // Send APPROVED refund email
        const approvedMailOptions = {
            from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
            to: email,
            subject: `[TEST] Refund Approved - Order #${mockData.orderId}`,
            html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:'Helvetica Neue',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.05);">
          <tr>
            <td style="background-color:#FF7733;padding:30px 40px;text-align:center;">
              <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:300;letter-spacing:2px;">CS308 SHOP</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 40px 20px;text-align:center;">
              <div style="width:70px;height:70px;background-color:#E8F5E9;border-radius:50%;margin:0 auto;display:flex;align-items:center;justify-content:center;">
                <span style="color:#4CAF50;font-size:36px;line-height:70px;">&#10003;</span>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 40px 40px;">
              <h2 style="color:#1a1a2e;margin:0 0 24px;font-size:24px;text-align:center;font-weight:400;">Refund Approved</h2>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 16px;">Dear ${mockData.userName},</p>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 30px;">Great news! Your refund request has been approved and processed successfully.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8f9fa;border-radius:8px;margin-bottom:30px;">
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Product</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${mockData.productName}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Order ID</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">#${mockData.orderId}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Quantity</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${mockData.refundQty}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Refund Amount</span><br>
                    <strong style="color:#4CAF50;font-size:22px;">$${mockData.refundAmount.toFixed(2)}</strong>
                  </td>
                </tr>
              </table>
              <p style="color:#6b7280;font-size:14px;line-height:1.6;margin:0;">The refund will be credited to your original payment method within <strong>5-10 business days</strong>.</p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f8f9fa;padding:24px 40px;text-align:center;border-top:1px solid #e5e7eb;">
              <p style="color:#9ca3af;font-size:12px;margin:0;">Thank you for shopping with us.</p>
              <p style="color:#9ca3af;font-size:12px;margin:8px 0 0;">© 2025 CS308 Shop. All rights reserved.</p>
              <p style="color:#FF7733;font-size:10px;margin:16px 0 0;font-weight:bold;">[THIS IS A TEST EMAIL]</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
            `
        };

        // Send REJECTED refund email
        const rejectedMailOptions = {
            from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
            to: email,
            subject: `[TEST] Refund Request Declined - Order #${mockData.orderId}`,
            html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:'Helvetica Neue',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.05);">
          <tr>
            <td style="background-color:#FF7733;padding:30px 40px;text-align:center;">
              <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:300;letter-spacing:2px;">CS308 SHOP</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 40px 20px;text-align:center;">
              <div style="width:70px;height:70px;background-color:#FFF3E0;border-radius:50%;margin:0 auto;display:flex;align-items:center;justify-content:center;">
                <span style="color:#FF7733;font-size:36px;line-height:70px;">!</span>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 40px 40px;">
              <h2 style="color:#1a1a2e;margin:0 0 24px;font-size:24px;text-align:center;font-weight:400;">Refund Request Declined</h2>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 16px;">Dear ${mockData.userName},</p>
              <p style="color:#6b7280;font-size:16px;line-height:1.6;margin:0 0 30px;">We have reviewed your refund request and unfortunately, we are unable to approve it at this time.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8f9fa;border-radius:8px;margin-bottom:30px;">
                <tr>
                  <td style="padding:16px 20px;border-bottom:1px solid #e5e7eb;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Product</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">${mockData.productName}</strong>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 20px;">
                    <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Order ID</span><br>
                    <strong style="color:#1a1a2e;font-size:16px;">#${mockData.orderId}</strong>
                  </td>
                </tr>
              </table>
              <div style="margin-bottom:30px;padding:20px;background-color:#fff8f0;border-left:3px solid #FF7733;border-radius:4px;">
                <span style="color:#9ca3af;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Reason</span><br>
                <p style="color:#1a1a2e;font-size:14px;line-height:1.6;margin:8px 0 0;">${mockData.reason}</p>
              </div>
              <p style="color:#6b7280;font-size:14px;line-height:1.6;margin:0 0 20px;">If you believe this decision was made in error or have additional information to provide, please don't hesitate to contact our customer support team.</p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:20px 0;">
                    <a href="mailto:support@cs308shop.com" style="display:inline-block;padding:14px 32px;background-color:#FF7733;color:#ffffff;text-decoration:none;border-radius:6px;font-size:14px;font-weight:500;">Contact Support</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f8f9fa;padding:24px 40px;text-align:center;border-top:1px solid #e5e7eb;">
              <p style="color:#9ca3af;font-size:12px;margin:0;">We appreciate your understanding.</p>
              <p style="color:#9ca3af;font-size:12px;margin:8px 0 0;">© 2025 CS308 Shop. All rights reserved.</p>
              <p style="color:#FF7733;font-size:10px;margin:16px 0 0;font-weight:bold;">[THIS IS A TEST EMAIL]</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
            `
        };

        // Send both emails
        await emailTransporter.sendMail(approvedMailOptions);
        console.log(`Test APPROVED refund email sent to ${email}`);

        await emailTransporter.sendMail(rejectedMailOptions);
        console.log(`Test REJECTED refund email sent to ${email}`);

        return res.json({
            success: true,
            message: `Two test refund emails (approved + rejected) sent to ${email}`
        });
    } catch (err) {
        console.error('Test email error:', err);
        return res.status(500).json({ error: 'Failed to send test emails', details: err.message });
    }
});

// DELETE /notifications/:id - Delete a notification
app.delete('/notifications/:id', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.uid || req.user.user_id;

        const notificationRef = db.collection('notifications').doc(id);
        const notificationDoc = await notificationRef.get();

        if (!notificationDoc.exists) {
            return res.status(404).json({ error: 'Notification not found' });
        }

        const notificationData = notificationDoc.data();
        // Check ownership - user can only delete their own notifications
        if (String(notificationData.user_id) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }

        await notificationRef.delete();

        return res.json({ success: true, message: 'Notification deleted' });
    } catch (err) {
        console.error('Delete notification error:', err);
        return res.status(500).json({ error: 'Failed to delete notification' });
    }
});

// ============================================
// REVENUE & PROFIT/LOSS ENDPOINTS (Sales Manager)
// ============================================

// GET /revenue - Calculate revenue and profit/loss between dates
app.get('/revenue', authenticate, authorize(['sales_manager', 'admin']), async (req, res) => {
    try {
        const { start_date, end_date } = req.query;
        
        if (!start_date || !end_date) {
            return res.status(400).json({ error: 'start_date and end_date are required (ISO format)' });
        }
        
        const startDate = new Date(start_date);
        const endDate = new Date(end_date);
        
        if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
            return res.status(400).json({ error: 'Invalid date format. Use ISO format (YYYY-MM-DD)' });
        }
        
        // Set start date to beginning of day (00:00:00)
        startDate.setHours(0, 0, 0, 0);
        // Set end date to end of day (23:59:59)
        endDate.setHours(23, 59, 59, 999);
        
        // Get all delivered orders (we'll filter by date in JavaScript to avoid index issues)
        let ordersSnapshot;
        try {
            ordersSnapshot = await db.collection('orders')
                .where('status', '==', 'delivered')
                .get();
        } catch (err) {
            // If query fails, try without status filter
            console.error('Error querying orders:', err);
            ordersSnapshot = await db.collection('orders').get();
        }
        
        // Get all products to build cost map (for efficient cost lookup)
        const productsSnapshot = await db.collection('products').get();
        const productCostMap = {}; // { product_id: cost }
        productsSnapshot.docs.forEach(doc => {
            const productData = doc.data();
            const productId = String(productData.product_id || doc.id);
            // Use product cost if specified, otherwise default to 50% of price
            if (productData.cost !== undefined && productData.cost !== null) {
                productCostMap[productId] = Number(productData.cost);
            } else {
                const price = Number(productData.price || 0);
                productCostMap[productId] = price * 0.5; // 50% default
            }
        });
        
        let totalRevenue = 0;
        let totalCost = 0;
        const dailyData = {}; // { 'YYYY-MM-DD': { revenue, cost, profit } }
        
        for (const doc of ordersSnapshot.docs) {
            const orderData = doc.data();
            
            // Skip if not delivered
            if (orderData.status !== 'delivered') {
                continue;
            }
            
            // Get order date
            let orderDateObj = null;
            if (orderData.created_at && typeof orderData.created_at.toDate === 'function') {
                orderDateObj = orderData.created_at.toDate();
            } else if (orderData.date) {
                if (typeof orderData.date.toDate === 'function') {
                    orderDateObj = orderData.date.toDate();
                } else if (typeof orderData.date === 'string') {
                    orderDateObj = new Date(orderData.date);
                } else {
                    orderDateObj = new Date(orderData.date);
                }
            }
            
            // Skip if no valid date
            if (!orderDateObj || isNaN(orderDateObj.getTime())) {
                continue;
            }
            
            // Filter by date range
            if (orderDateObj < startDate || orderDateObj > endDate) {
                continue;
            }
            
            const orderTotal = orderData.total_amount || 0;
            
            // Calculate cost using product cost (if specified) or 50% default
            let orderCost = 0;
            if (orderData.items && Array.isArray(orderData.items)) {
                orderCost = orderData.items.reduce((sum, item) => {
                    const productId = String(item.product_id || '');
                    const quantity = Number(item.quantity || 1);
                    const unitPrice = Number(item.unit_price || 0);
                    
                    // Get product cost from map, or use 50% of unit price as fallback
                    const unitCost = productCostMap[productId] !== undefined 
                        ? productCostMap[productId]
                        : (unitPrice * 0.5); // 50% fallback
                    
                    return sum + (unitCost * quantity);
                }, 0);
            }
            
            totalRevenue += orderTotal;
            totalCost += orderCost;
            
            // Group by date
            const orderDate = orderDateObj.toISOString().split('T')[0];
            
            if (orderDate) {
                if (!dailyData[orderDate]) {
                    dailyData[orderDate] = { revenue: 0, cost: 0, profit: 0 };
                }
                dailyData[orderDate].revenue += orderTotal;
                dailyData[orderDate].cost += orderCost;
                dailyData[orderDate].profit += (orderTotal - orderCost);
            }
        }
        
        const totalProfit = totalRevenue - totalCost;
        
        // Count filtered orders
        const filteredOrderCount = Object.values(dailyData).reduce((sum, data) => {
            // This is approximate - we count unique dates
            return sum + 1;
        }, 0);
        
        // Convert daily data to array sorted by date
        const dailyChartData = Object.entries(dailyData)
            .map(([date, data]) => ({
                date: date,
                revenue: Number(data.revenue.toFixed(2)),
                cost: Number(data.cost.toFixed(2)),
                profit: Number(data.profit.toFixed(2))
            }))
            .sort((a, b) => a.date.localeCompare(b.date));
        
        // Count actual orders processed (we need to track this)
        let actualOrderCount = 0;
        for (const doc of ordersSnapshot.docs) {
            const orderData = doc.data();
            if (orderData.status !== 'delivered') continue;
            
            let orderDateObj = null;
            if (orderData.created_at && typeof orderData.created_at.toDate === 'function') {
                orderDateObj = orderData.created_at.toDate();
            } else if (orderData.date) {
                if (typeof orderData.date.toDate === 'function') {
                    orderDateObj = orderData.date.toDate();
                } else {
                    orderDateObj = new Date(orderData.date);
                }
            }
            
            if (orderDateObj && !isNaN(orderDateObj.getTime())) {
                if (orderDateObj >= startDate && orderDateObj <= endDate) {
                    actualOrderCount++;
                }
            }
        }
        
        return res.json({
            period: {
                start_date: start_date,
                end_date: end_date
            },
            summary: {
                total_revenue: Number(totalRevenue.toFixed(2)),
                total_cost: Number(totalCost.toFixed(2)),
                total_profit: Number(totalProfit.toFixed(2)),
                profit_margin: totalRevenue > 0 
                    ? Number(((totalProfit / totalRevenue) * 100).toFixed(2))
                    : 0
            },
            daily_data: dailyChartData,
            order_count: actualOrderCount
        });
    } catch (err) {
        console.error('Calculate revenue error:', err);
        return res.status(500).json({ error: 'Failed to calculate revenue', details: err.message });
    }
});

// ============================================
// INVOICE MANAGEMENT ENDPOINTS (11.4 - Sales Manager)
// ============================================

// GET /invoices - Sales manager & Product manager views invoices in date range
app.get('/invoices', authenticate, authorize(['sales_manager', 'product_manager', 'admin']), async (req, res) => {
    try {
        const { start_date, end_date, status } = req.query;
        
        let query = db.collection('orders');
        
        // Filter by date range if provided
        if (start_date || end_date) {
            const startDate = start_date ? new Date(start_date) : new Date(0);
            const endDate = end_date ? new Date(end_date) : new Date();
            
            // Firestore timestamp queries
            if (start_date) {
                query = query.where('created_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
            }
            if (end_date) {
                query = query.where('created_at', '<=', admin.firestore.Timestamp.fromDate(endDate));
            }
        }
        
        // Filter by status if provided
        if (status) {
            query = query.where('status', '==', status);
        }
        
        let snapshot;
        try {
            snapshot = await query.orderBy('created_at', 'desc').limit(100).get();
        } catch (e) {
            // If index doesn't exist, fetch without orderBy
            snapshot = await query.limit(100).get();
        }
        
        const invoices = [];
        for (const doc of snapshot.docs) {
            const orderData = doc.data();
            
            // Get user info
            let userInfo = {};
            try {
                const userDoc = await db.collection('users').doc(String(orderData.user_id)).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    userInfo = {
                        name: userData.name || 'Unknown',
                        email: userData.email || 'N/A',
                        address: userData.address || 'N/A'
                    };
                }
            } catch (e) {
                console.error(`Error fetching user ${orderData.user_id}:`, e);
            }
            
            // Format date
            let orderDate = '';
            if (orderData.created_at && typeof orderData.created_at.toDate === 'function') {
                orderDate = orderData.created_at.toDate().toISOString();
            } else if (orderData.date) {
                if (typeof orderData.date.toDate === 'function') {
                    orderDate = orderData.date.toDate().toISOString();
                } else {
                    orderDate = orderData.date.toString();
                }
            } else {
                orderDate = new Date().toISOString();
            }
            
            invoices.push({
                order_id: orderData.order_id,
                user_id: orderData.user_id,
                user: userInfo,
                status: orderData.status,
                total_amount: orderData.total_amount || 0,
                items: orderData.items || [],
                delivery_address: orderData.delivery_address || 'N/A',
                created_at: orderDate,
                date: orderDate
            });
        }
        
        // Sort by date descending if we couldn't use orderBy
        invoices.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        
        return res.json({ 
            invoices,
            count: invoices.length,
            filters: {
                start_date: start_date || null,
                end_date: end_date || null,
                status: status || null
            }
        });
    } catch (err) {
        console.error('Get invoices error:', err);
        return res.status(500).json({ error: 'Failed to fetch invoices', details: err.message });
    }
});

// GET /invoices/:orderId/pdf - Generate and download PDF invoice
app.get('/invoices/:orderId/pdf', authenticate, authorize(['sales_manager', 'product_manager', 'admin']), async (req, res) => {
    try {
        const { orderId } = req.params;
        
        const orderRef = db.collection('orders').doc(String(orderId));
        const orderDoc = await orderRef.get();
        
        if (!orderDoc.exists) {
            return res.status(404).json({ error: 'Order not found' });
        }
        
        const orderData = orderDoc.data();
        
        // Get user email
        let userEmail = 'customer@example.com';
        try {
            const userDoc = await db.collection('users').doc(String(orderData.user_id)).get();
            if (userDoc.exists) {
                userEmail = userDoc.data().email || userEmail;
            }
        } catch (e) {
            console.error('Error fetching user email:', e);
        }
        
        // Generate PDF
        const pdfPath = await generateInvoicePDF(orderData, userEmail);
        
        // Send PDF as response
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename=invoice_${orderData.order_id}.pdf`);
        
        const fileStream = fs.createReadStream(pdfPath);
        fileStream.pipe(res);
        
        // Clean up file after sending
        fileStream.on('end', () => {
            setTimeout(() => {
                try {
                    fs.unlinkSync(pdfPath);
                } catch (e) {
                    console.error('Error deleting temp PDF:', e);
                }
            }, 1000);
        });
    } catch (err) {
        console.error('Generate PDF invoice error:', err);
        return res.status(500).json({ error: 'Failed to generate PDF invoice', details: err.message });
    }
});

// ============================================
// USER INFORMATION ENDPOINTS
// ============================================

// GET /users/:uid/info - Get user information
app.get('/users/:uid/info', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only access their own info (or admin)
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const userDoc = await db.collection('users').doc(String(uid)).get();
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        const userData = userDoc.data();
        
        // Return user info (including password for viewing/editing on My Information page)
        return res.json({
            id: userDoc.id,
            user_id: userData.user_id,
            name: userData.name || '',
            email: userData.email || '',
            address: userData.address || '',
            taxID: userData.taxID || '',
            role: userData.role || 'customer',
            created_at: userData.created_at || null
        });
    } catch (err) {
        console.error('Get user info error:', err);
        return res.status(500).json({ error: 'Failed to fetch user information', details: err.message });
    }
});

// PUT /users/:uid/info - Update user information
app.put('/users/:uid/info', authenticate, async (req, res) => {
    try {
        const { uid } = req.params;
        const { name, email, address, taxID, password } = req.body;
        const userId = req.user.uid || req.user.user_id;
        
        // Verify user can only update their own info (or admin)
        if (String(uid) !== String(userId) && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        
        const userRef = db.collection('users').doc(String(uid));
        const userDoc = await userRef.get();
        
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        const updates = {};
        
        // Update name if provided
        if (name !== undefined) {
            updates.name = name;
        }
        
        // Update email if provided (check for duplicates)
        if (email !== undefined) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(email)) {
                return res.status(400).json({ error: 'Invalid email format' });
            }
            
            // Check if email is already used by another user
            const emailCheck = await db.collection('users')
                .where('email', '==', email)
                .limit(1)
                .get();
            
            if (!emailCheck.empty && emailCheck.docs[0].id !== String(uid)) {
                return res.status(409).json({ error: 'Email already registered' });
            }
            
            updates.email = email;
        }
        
        // Update address if provided
        if (address !== undefined) {
            updates.address = address;
        }
        
        // Update taxID if provided
        if (taxID !== undefined) {
            updates.taxID = taxID;
        }
        
        // Update password if provided
        if (password !== undefined) {
            if (password.length < 6) {
                return res.status(400).json({ error: 'Password too short (minimum 6 characters)' });
            }
            const saltRounds = 10;
            updates.password = await bcrypt.hash(password, saltRounds);
        }
        
        // Add updated_at timestamp
        updates.updated_at = FieldValue.serverTimestamp();
        
        // Apply updates
        await userRef.update(updates);
        
        // Fetch updated user data
        const updatedDoc = await userRef.get();
        const updatedData = updatedDoc.data();
        
        return res.json({
            success: true,
            message: 'User information updated successfully',
            user: {
                id: updatedDoc.id,
                user_id: updatedData.user_id,
                name: updatedData.name || '',
                email: updatedData.email || '',
                address: updatedData.address || '',
                taxID: updatedData.taxID || '',
                role: updatedData.role || 'customer'
            }
        });
    } catch (err) {
        console.error('Update user info error:', err);
        return res.status(500).json({ error: 'Failed to update user information', details: err.message });
    }
});

// Image proxy endpoint to avoid CORS issues
app.get('/images/:filename(*)', async (req, res) => {
    try {
        const filename = decodeURIComponent(req.params.filename);
        const file = bucket.file(`products/${filename}`);
        
        const [exists] = await file.exists();
        if (!exists) {
            return res.status(404).json({ error: 'Image not found' });
        }
        
        const [fileBuffer] = await file.download();
        const [metadata] = await file.getMetadata();
        
        res.setHeader('Content-Type', metadata.contentType || 'image/png');
        res.setHeader('Cache-Control', 'public, max-age=31536000');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.send(fileBuffer);
    } catch (error) {
        console.error('Image proxy error:', error);
        res.status(500).json({ error: 'Failed to load image' });
    }
});

// =====================================================
// 12.1 - PRODUCT MANAGER: Product & Category Management
// =====================================================

// GET /products/manage - Get all products for management (with stock info)
app.get('/products/manage', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const snapshot = await db.collection('products').get();
        const products = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));
        return res.json({ products });
    } catch (err) {
        console.error('Get products for management error:', err);
        return res.status(500).json({ error: 'Failed to fetch products' });
    }
});

// POST /products - Add new product
app.post('/products', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const {
            name,
            description,
            price,
            category,
            quantity_in_stock,
            model,
            serial_number,
            warranty_status,
            distributor_info,
            image_url
        } = req.body;

        if (!name || price === undefined || quantity_in_stock === undefined) {
            return res.status(400).json({ error: 'Name, price, and quantity_in_stock are required' });
        }

        // Get max product_id
        const allProducts = await db.collection('products').get();
        let maxId = 0;
        allProducts.forEach(doc => {
            const pid = doc.data().product_id;
            if (typeof pid === 'number' && pid > maxId) maxId = pid;
        });
        const newProductId = maxId + 1;

        const newProduct = {
            product_id: newProductId,
            name,
            description: description || '',
            price: Number(price),
            category: category || 'Uncategorized',
            quantity_in_stock: Number(quantity_in_stock),
            model: model || '',
            serial_number: serial_number || '',
            warranty_status: warranty_status || '',
            distributor_info: distributor_info || '',
            image_url: image_url || '',
            created_at: FieldValue.serverTimestamp(),
            updated_at: FieldValue.serverTimestamp()
        };

        const docRef = await db.collection('products').add(newProduct);

        return res.status(201).json({
            success: true,
            message: 'Product created successfully',
            product: { id: docRef.id, ...newProduct }
        });
    } catch (err) {
        console.error('Create product error:', err);
        return res.status(500).json({ error: 'Failed to create product', details: err.message });
    }
});

// PUT /products/:id - Update product
app.put('/products/:id', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;

        // Remove fields that shouldn't be updated directly
        delete updates.product_id;
        delete updates.created_at;

        if (Object.keys(updates).length === 0) {
            return res.status(400).json({ error: 'No update fields provided' });
        }

        // Convert numeric fields
        if (updates.price !== undefined) updates.price = Number(updates.price);
        if (updates.quantity_in_stock !== undefined) updates.quantity_in_stock = Number(updates.quantity_in_stock);

        updates.updated_at = FieldValue.serverTimestamp();

        const productRef = db.collection('products').doc(id);
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        await productRef.update(updates);
        const updatedDoc = await productRef.get();

        return res.json({
            success: true,
            message: 'Product updated successfully',
            product: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (err) {
        console.error('Update product error:', err);
        return res.status(500).json({ error: 'Failed to update product', details: err.message });
    }
});

// DELETE /products/:id - Remove product
app.delete('/products/:id', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;

        const productRef = db.collection('products').doc(id);
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        await productRef.delete();

        return res.json({
            success: true,
            message: 'Product deleted successfully'
        });
    } catch (err) {
        console.error('Delete product error:', err);
        return res.status(500).json({ error: 'Failed to delete product', details: err.message });
    }
});

// =====================================================
// 12.1 - PRODUCT MANAGER: Stock Management
// =====================================================

// PUT /products/:id/stock - Update product stock
app.put('/products/:id/stock', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const { id } = req.params;
        const { quantity_in_stock, adjustment } = req.body;

        const productRef = db.collection('products').doc(id);
        const productDoc = await productRef.get();

        if (!productDoc.exists) {
            return res.status(404).json({ error: 'Product not found' });
        }

        let updateData = { updated_at: FieldValue.serverTimestamp() };

        if (adjustment !== undefined) {
            // Relative adjustment (add or subtract)
            updateData.quantity_in_stock = FieldValue.increment(Number(adjustment));
        } else if (quantity_in_stock !== undefined) {
            // Absolute value
            updateData.quantity_in_stock = Number(quantity_in_stock);
        } else {
            return res.status(400).json({ error: 'Provide quantity_in_stock or adjustment' });
        }

        await productRef.update(updateData);
        const updatedDoc = await productRef.get();

        return res.json({
            success: true,
            message: 'Stock updated successfully',
            product: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (err) {
        console.error('Update stock error:', err);
        return res.status(500).json({ error: 'Failed to update stock', details: err.message });
    }
});

// =====================================================
// 12.1 - PRODUCT MANAGER: Category Management
// =====================================================

// GET /categories - Get all categories
// Query param: ?include_empty=true to include categories without products
app.get('/categories', async (req, res) => {
    try {
        const includeEmpty = req.query.include_empty === 'true';
        
        // Get categories from products (these have actual products)
        const snapshot = await db.collection('products').get();
        const productCategories = new Set();
        
        snapshot.forEach(doc => {
            const category = doc.data().category;
            if (category) productCategories.add(category);
        });

        // If include_empty, also add categories from categories collection
        if (includeEmpty) {
            try {
                const categoriesSnapshot = await db.collection('categories').get();
                categoriesSnapshot.forEach(doc => {
                    const catName = doc.data().name;
                    if (catName) productCategories.add(catName);
                });
            } catch (e) {
                // Categories collection might not exist
            }
        }

        const categories = Array.from(productCategories).sort();

        return res.json({ categories });
    } catch (err) {
        console.error('Get categories error:', err);
        return res.status(500).json({ error: 'Failed to fetch categories' });
    }
});

// POST /categories - Add new category
app.post('/categories', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const { name, description } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Category name is required' });
        }

        // Check if category already exists
        const existingSnapshot = await db.collection('categories')
            .where('name', '==', name)
            .get();

        if (!existingSnapshot.empty) {
            return res.status(400).json({ error: 'Category already exists' });
        }

        const newCategory = {
            name,
            description: description || '',
            created_at: FieldValue.serverTimestamp()
        };

        const docRef = await db.collection('categories').add(newCategory);

        return res.status(201).json({
            success: true,
            message: 'Category created successfully',
            category: { id: docRef.id, ...newCategory }
        });
    } catch (err) {
        console.error('Create category error:', err);
        return res.status(500).json({ error: 'Failed to create category', details: err.message });
    }
});

// DELETE /categories/:name - Remove category
app.delete('/categories/:name', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const { name } = req.params;

        // Find and delete the category
        const snapshot = await db.collection('categories')
            .where('name', '==', decodeURIComponent(name))
            .get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'Category not found' });
        }

        const batch = db.batch();
        snapshot.forEach(doc => {
            batch.delete(doc.ref);
        });
        await batch.commit();

        return res.json({
            success: true,
            message: 'Category deleted successfully'
        });
    } catch (err) {
        console.error('Delete category error:', err);
        return res.status(500).json({ error: 'Failed to delete category', details: err.message });
    }
});

// =====================================================
// 12.2 & 12.3 - PRODUCT MANAGER: Delivery List with Full Details
// =====================================================

// GET /deliveries - Get delivery list with all required fields (12.3)
app.get('/deliveries', authenticate, authorize(['product_manager', 'admin']), async (req, res) => {
    try {
        const snapshot = await db.collection('orders')
            .where('status', 'in', ['processing', 'in-transit', 'delivered'])
            .get();

        const deliveries = snapshot.docs.map(doc => {
            const data = doc.data();
            const items = data.items || [];
            
            return {
                delivery_id: doc.id,
                order_id: data.order_id || doc.id,
                customer_id: data.user_id,
                items: items.map(item => ({
                    product_id: item.product_id,
                    quantity: item.quantity,
                    unit_price: item.unit_price || 0
                })),
                total_price: data.total_amount || 0,
                delivery_address: data.delivery_address || 'N/A',
                status: data.status,
                completion_status: data.status === 'delivered' ? 'completed' : 'pending',
                created_at: data.created_at,
                updated_at: data.updated_at
            };
        });

        // Sort by status priority
        deliveries.sort((a, b) => {
            const statusPriority = { 'processing': 1, 'in-transit': 2, 'delivered': 3 };
            return (statusPriority[a.status] || 999) - (statusPriority[b.status] || 999);
        });

        return res.json({ deliveries, count: deliveries.length });
    } catch (err) {
        console.error('Get deliveries error:', err);
        return res.status(500).json({ error: 'Failed to fetch deliveries' });
    }
});

// ==================== LIVE CHAT ENDPOINTS ====================

// Customer initiates a chat (guest or logged-in)
app.post('/chat/initiate', optionalAuthenticate, async (req, res) => {
    try {
        const { customerName, customerEmail } = req.body;
        const userId = req.user?.uid || null; // null if guest

        // Build chat data object, only including defined values
        const chatData = {
            status: 'active', // active, claimed, closed
            createdAt: FieldValue.serverTimestamp(),
            lastMessageAt: FieldValue.serverTimestamp()
        };

        // Add userId if logged in
        if (userId) {
            chatData.userId = userId;
        }

        // Add guest info if not logged in
        if (!userId) {
            if (customerName) chatData.customerName = customerName;
            if (customerEmail) chatData.customerEmail = customerEmail;
        }

        // Create a new chat conversation
        const chatRef = await db.collection('chats').add(chatData);

        return res.status(201).json({
            chatId: chatRef.id,
            message: 'Chat initiated successfully'
        });
    } catch (err) {
        console.error('Chat initiate error:', err);
        return res.status(500).json({ error: 'Failed to initiate chat' });
    }
});

// Customer sends a message (with optional file attachments)
app.post('/chat/:chatId/messages', optionalAuthenticate, async (req, res) => {
    try {
        const { chatId } = req.params;
        const { message, attachments } = req.body; // attachments: [{url, type, name}]
        const userId = req.user?.uid || null;

        // Verify chat exists
        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Prevent sending messages to closed chats
        if (chatData.status === 'closed') {
            return res.status(400).json({ error: 'Cannot send messages to a closed chat' });
        }

        // Add message to messages subcollection
        const messageRef = await db.collection('chats').doc(chatId).collection('messages').add({
            senderId: userId,
            sender: 'customer', // customer or support
            senderType: 'customer', // customer or agent
            message: message || '',
            attachments: attachments || [],
            createdAt: FieldValue.serverTimestamp(),
            read: false
        });

        // Update chat's lastMessageAt
        await db.collection('chats').doc(chatId).update({
            lastMessageAt: FieldValue.serverTimestamp()
        });

        return res.status(201).json({
            messageId: messageRef.id,
            message: 'Message sent successfully'
        });
    } catch (err) {
        console.error('Send message error:', err);
        return res.status(500).json({ error: 'Failed to send message' });
    }
});

// Customer retrieves chat messages
app.get('/chat/:chatId/messages', optionalAuthenticate, async (req, res) => {
    try {
        const { chatId } = req.params;
        const userId = req.user?.uid || null;

        // Verify chat exists
        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Verify user has access to this chat (either their chat or they're the assigned agent)
        if (userId && chatData.userId !== userId && chatData.claimedBy !== userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Get all messages
        const messagesSnapshot = await db.collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('createdAt', 'asc')
            .get();

        const messages = messagesSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate()
        }));

        return res.json({
            messages,
            chatStatus: chatData.status || 'active'
        });
    } catch (err) {
        console.error('Get messages error:', err);
        return res.status(500).json({ error: 'Failed to fetch messages' });
    }
});

// Upload file for chat attachment
app.post('/chat/upload', async (req, res) => {
    try {
        const { fileName, fileData, mimeType } = req.body;

        if (!fileName || !fileData) {
            return res.status(400).json({ error: 'fileName and fileData required' });
        }

        // Decode base64 file data
        const buffer = Buffer.from(fileData, 'base64');

        // Generate unique filename
        const timestamp = Date.now();
        const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
        const storagePath = `chat-attachments/${timestamp}_${sanitizedFileName}`;

        // Upload to Firebase Storage
        const file = bucket.file(storagePath);
        await file.save(buffer, {
            metadata: {
                contentType: mimeType || 'application/octet-stream'
            }
        });

        // Generate signed URL (valid for 7 days)
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 7 * 24 * 60 * 60 * 1000
        });

        return res.json({
            url,
            fileName: sanitizedFileName,
            mimeType: mimeType || 'application/octet-stream'
        });
    } catch (err) {
        console.error('File upload error:', err);
        return res.status(500).json({ error: 'Failed to upload file' });
    }
});

// Customer: Get my chats (both active and history)
app.get('/chat/my-chats', optionalAuthenticate, async (req, res) => {
    try {
        const userId = req.user?.uid || null;
        const { email } = req.query; // For guest users

        if (!userId && !email) {
            return res.status(400).json({ error: 'User not authenticated and no email provided' });
        }

        let chatsSnapshot;

        if (userId) {
            // Get chats for logged-in user
            chatsSnapshot = await db.collection('chats')
                .where('userId', '==', userId)
                .orderBy('lastMessageAt', 'desc')
                .get();
        } else {
            // Get chats for guest user by email
            chatsSnapshot = await db.collection('chats')
                .where('customerEmail', '==', email)
                .orderBy('lastMessageAt', 'desc')
                .get();
        }

        const chats = await Promise.all(chatsSnapshot.docs.map(async doc => {
            const chatData = doc.data();

            // Get last message
            const lastMessageSnapshot = await db.collection('chats')
                .doc(doc.id)
                .collection('messages')
                .orderBy('createdAt', 'desc')
                .limit(1)
                .get();

            let lastMessage = null;
            if (!lastMessageSnapshot.empty) {
                const msgData = lastMessageSnapshot.docs[0].data();
                lastMessage = {
                    text: msgData.message || '',
                    sender: msgData.sender || '',
                    createdAt: msgData.createdAt?.toDate()
                };
            }

            // Count unread messages (messages from support agent that customer hasn't read)
            const unreadSnapshot = await db.collection('chats')
                .doc(doc.id)
                .collection('messages')
                .where('sender', '==', 'support')
                .where('read', '==', false)
                .get();

            return {
                id: doc.id,
                status: chatData.status,
                createdAt: chatData.createdAt?.toDate(),
                lastMessageAt: chatData.lastMessageAt?.toDate(),
                claimedBy: chatData.claimedBy || null,
                lastMessage,
                unreadCount: unreadSnapshot.size
            };
        }));

        return res.json({ chats });
    } catch (err) {
        console.error('Get my chats error:', err);
        return res.status(500).json({ error: 'Failed to fetch chats' });
    }
});

// Support Agent: View chat queue (all active chats)
app.get('/support/chats/queue', authenticate, authorize(['support_agent', 'admin']), async (req, res) => {
    try {
        const chatsSnapshot = await db.collection('chats')
            .where('status', 'in', ['active', 'claimed'])
            .orderBy('lastMessageAt', 'desc')
            .get();

        const chats = await Promise.all(chatsSnapshot.docs.map(async doc => {
            const chatData = doc.data();
            let customerInfo = {
                name: chatData.customerName || 'Guest',
                email: chatData.customerEmail || null
            };

            // If logged-in customer, fetch their profile
            if (chatData.userId) {
                const userDoc = await db.collection('users').doc(chatData.userId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    customerInfo = {
                        name: userData.name || 'Customer',
                        email: userData.email || null,
                        userId: chatData.userId
                    };
                }
            }

            // Get last message
            const lastMsgSnapshot = await db.collection('chats')
                .doc(doc.id)
                .collection('messages')
                .orderBy('createdAt', 'desc')
                .limit(1)
                .get();

            const lastMessage = lastMsgSnapshot.empty ? null : {
                ...lastMsgSnapshot.docs[0].data(),
                createdAt: lastMsgSnapshot.docs[0].data().createdAt?.toDate()
            };

            // Get unread count
            const unreadSnapshot = await db.collection('chats')
                .doc(doc.id)
                .collection('messages')
                .where('senderType', '==', 'customer')
                .where('read', '==', false)
                .get();

            return {
                id: doc.id,
                ...chatData,
                customerInfo,
                lastMessage,
                unreadCount: unreadSnapshot.size,
                createdAt: chatData.createdAt?.toDate(),
                lastMessageAt: chatData.lastMessageAt?.toDate(),
                claimedAt: chatData.claimedAt?.toDate()
            };
        }));

        return res.json({ chats });
    } catch (err) {
        console.error('Get chat queue error:', err);
        return res.status(500).json({ error: 'Failed to fetch chat queue' });
    }
});

// Support Agent: Claim a chat from the queue
app.post('/support/chats/:chatId/claim', authenticate, authorize(['support_agent', 'admin']), async (req, res) => {
    try {
        const { chatId } = req.params;
        const agentId = req.user.uid;

        const chatRef = db.collection('chats').doc(chatId);
        const chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Check if already claimed
        if (chatData.claimedBy && chatData.claimedBy !== agentId) {
            return res.status(409).json({ error: 'Chat already claimed by another agent' });
        }

        // Claim the chat
        await chatRef.update({
            status: 'claimed',
            claimedBy: agentId,
            claimedAt: FieldValue.serverTimestamp()
        });

        return res.json({ message: 'Chat claimed successfully' });
    } catch (err) {
        console.error('Claim chat error:', err);
        return res.status(500).json({ error: 'Failed to claim chat' });
    }
});

// Support Agent: Send a response
app.post('/support/chats/:chatId/respond', authenticate, authorize(['support_agent', 'admin']), async (req, res) => {
    try {
        const { chatId } = req.params;
        const { message, attachments } = req.body;
        const agentId = req.user.uid;

        const chatRef = db.collection('chats').doc(chatId);
        const chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Verify agent has claimed this chat
        if (chatData.claimedBy !== agentId) {
            return res.status(403).json({ error: 'You must claim this chat first' });
        }

        // Add agent response to messages
        const messageRef = await db.collection('chats').doc(chatId).collection('messages').add({
            senderId: agentId,
            sender: 'support', // customer or support
            senderType: 'agent',
            message: message || '',
            attachments: attachments || [],
            createdAt: FieldValue.serverTimestamp(),
            read: false
        });

        // Update chat's lastMessageAt
        await chatRef.update({
            lastMessageAt: FieldValue.serverTimestamp()
        });

        return res.status(201).json({
            messageId: messageRef.id,
            message: 'Response sent successfully'
        });
    } catch (err) {
        console.error('Send response error:', err);
        return res.status(500).json({ error: 'Failed to send response' });
    }
});

// Support Agent: Get customer context (if logged in)
app.get('/support/chats/:chatId/customer-context', authenticate, authorize(['support_agent', 'admin']), async (req, res) => {
    try {
        const { chatId } = req.params;
        const agentId = req.user.uid;

        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Verify agent has claimed this chat
        if (chatData.claimedBy !== agentId) {
            return res.status(403).json({ error: 'You must claim this chat first' });
        }

        if (!chatData.userId) {
            return res.json({
                isGuest: true,
                customerName: chatData.customerName,
                customerEmail: chatData.customerEmail
            });
        }

        // Get customer profile
        const userDoc = await db.collection('users').doc(chatData.userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({ error: 'Customer not found' });
        }

        const userData = userDoc.data();

        // Get customer's recent orders (try both created_at and createdAt fields)
        let ordersSnapshot;
        try {
            ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', chatData.userId)
                .orderBy('created_at', 'desc')
                .limit(5)
                .get();
        } catch (e) {
            // If created_at index doesn't exist, try without ordering
            console.log('Orders query with created_at failed, trying without order:', e.message);
            ordersSnapshot = await db.collection('orders')
                .where('user_id', '==', chatData.userId)
                .limit(5)
                .get();
        }

        const orders = ordersSnapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                created_at: data.created_at?.toDate ? data.created_at.toDate() : data.created_at,
                createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : data.createdAt
            };
        });

        // Get customer's cart
        const cartSnapshot = await db.collection('cart')
            .where('user_id', '==', chatData.userId)
            .get();

        const cartItems = cartSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        // Get customer's wishlist
        const wishlistSnapshot = await db.collection('wishlists')
            .where('user_id', '==', chatData.userId)
            .get();

        const wishlistItems = wishlistSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        return res.json({
            isGuest: false,
            profile: {
                uid: chatData.userId,
                name: userData.name,
                email: userData.email,
                role: userData.role,
                created_at: userData.created_at?.toDate ? userData.created_at.toDate() : userData.created_at
            },
            recentOrders: orders,
            cart: cartItems,
            wishlist: wishlistItems
        });
    } catch (err) {
        console.error('Get customer context error:', err);
        return res.status(500).json({ error: 'Failed to fetch customer context' });
    }
});

// Support Agent: Close a chat
app.put('/support/chats/:chatId/close', authenticate, authorize(['support_agent', 'admin']), async (req, res) => {
    try {
        const { chatId } = req.params;
        const agentId = req.user.uid;

        const chatRef = db.collection('chats').doc(chatId);
        const chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
            return res.status(404).json({ error: 'Chat not found' });
        }

        const chatData = chatDoc.data();

        // Verify agent has claimed this chat
        if (chatData.claimedBy !== agentId) {
            return res.status(403).json({ error: 'You can only close chats you have claimed' });
        }

        await chatRef.update({
            status: 'closed',
            closedAt: FieldValue.serverTimestamp()
        });

        return res.json({ message: 'Chat closed successfully' });
    } catch (err) {
        console.error('Close chat error:', err);
        return res.status(500).json({ error: 'Failed to close chat' });
    }
});

// Mark messages as read
app.put('/chat/:chatId/messages/read', async (req, res) => {
    try {
        const { chatId } = req.params;
        const { messageIds } = req.body; // array of message IDs to mark as read
        const userId = req.user?.uid || null;

        if (!messageIds || !Array.isArray(messageIds)) {
            return res.status(400).json({ error: 'messageIds array required' });
        }

        // Update messages in batch
        const batch = db.batch();
        for (const messageId of messageIds) {
            const messageRef = db.collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(messageId);
            batch.update(messageRef, { read: true });
        }
        await batch.commit();

        return res.json({ message: 'Messages marked as read' });
    } catch (err) {
        console.error('Mark messages read error:', err);
        return res.status(500).json({ error: 'Failed to mark messages as read' });
    }
});

require('./auth-routes')(app, db);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Server listening on http://localhost:${PORT}`);
    });
}

module.exports = app;
