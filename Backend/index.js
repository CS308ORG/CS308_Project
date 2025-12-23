require('dotenv').config();
const express = require('express');
const cors = require('cors');
const app = express();
const jwt = require('jsonwebtoken');

app.use(cors());
app.use(express.json());

const admin = require('firebase-admin');
const JWT_SECRET = process.env.JWT_SECRET || 'cs308-secret-key-change-in-production';

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH;
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

const bcrypt = require('bcrypt');
const nodemailer = require('nodemailer');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

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

                return {
                    ...doc,
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
                created_at: FieldValue.serverTimestamp(),
                date: new Date().toISOString()
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

        const orders = [];
        for (const orderDoc of ordersSnapshot.docs) {
            const orderData = orderDoc.data();
            const orderId = orderData.order_id;

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
                        if (productDoc.exists) productDetails = productDoc.data();
                    } catch (e) { }
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
                    refund_status: refundStatus || item.refund_status || null
                });
            }

            const createdAt = orderData.created_at && typeof orderData.created_at.toDate === 'function'
                ? orderData.created_at.toDate().toISOString()
                : (orderData.date || new Date().toISOString());
            orders.push({
                ...orderData,
                items: enrichedItems,
                date: createdAt,
                created_at: createdAt // Also include created_at for frontend
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

        // Create refund request
        // Store the original unit_price to preserve purchase-time discount
        const refundData = {
            refund_id: refundId,
            order_id: Number(order_id),
            product_id: Number(product_id),
            user_id: userId,
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

        // Use transaction for atomic operations
        await db.runTransaction(async (tx) => {
            if (decisionNormalized === 'approved') {
                // Restore product stock
                const productRef = db.collection('products').doc(String(refundData.product_id));
                const productDoc = await tx.get(productRef);

                if (productDoc.exists) {
                    tx.update(productRef, {
                        quantity_in_stock: FieldValue.increment(refundData.quantity || 1)
                    });
                }

                // Update refund status
                tx.update(refundRef, {
                    status: 'refunded',
                    approved_by: req.user.uid || req.user.user_id,
                    approved_at: FieldValue.serverTimestamp(),
                    approval_reason: reason || null
                });

                // Update order status to show refund was accepted
                const orderRef = db.collection('orders').doc(String(refundData.order_id));
                const orderDoc = await tx.get(orderRef);
                if (orderDoc.exists) {
                    const orderData = orderDoc.data();
                    const items = orderData.items || [];
                    // Mark the specific item as refunded
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
                }
            } else {
                // Rejected
                tx.update(refundRef, {
                    status: 'rejected',
                    approved_by: req.user.uid || req.user.user_id,
                    approved_at: FieldValue.serverTimestamp(),
                    approval_reason: reason || null
                });

                // Update order to show refund was rejected
                const orderRef = db.collection('orders').doc(String(refundData.order_id));
                const orderDoc = await tx.get(orderRef);
                if (orderDoc.exists) {
                    const orderData = orderDoc.data();
                    const items = orderData.items || [];
                    // Mark the specific item as refund rejected
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
            }
        });

        // Send email notification if approved
        if (decisionNormalized === 'approved') {
            try {
                const userDoc = await db.collection('users').doc(String(refundData.user_id)).get();
                const userEmail = userDoc.exists ? userDoc.data().email : null;
                const userName = userDoc.exists ? userDoc.data().name : 'Customer';

                if (userEmail && emailTransporter) {
                    const productDoc = await db.collection('products').doc(String(refundData.product_id)).get();
                    const productName = productDoc.exists ? productDoc.data().name : 'Product';

                    const mailOptions = {
                        from: process.env.EMAIL_USER || 'noreply@cs308shop.com',
                        to: userEmail,
                        subject: `Refund Approved for Order #${refundData.order_id}`,
                        html: `
                            <h2>Refund Approved</h2>
                            <p>Dear ${userName},</p>
                            <p>Your refund request for <strong>${productName}</strong> from Order #${refundData.order_id} has been approved.</p>
                            <p><strong>Refund Amount:</strong> $${refundData.total_refund_amount.toFixed(2)}</p>
                            <p><strong>Quantity:</strong> ${refundData.quantity}</p>
                            <p>The refunded amount will be credited back to your original payment method.</p>
                            ${reason ? `<p><strong>Note:</strong> ${reason}</p>` : ''}
                            <br>
                            <p>Thank you for your patience.</p>
                            <p>Best regards,<br>CS308 Shop Team</p>
                        `
                    };

                    await emailTransporter.sendMail(mailOptions);
                    console.log(`Refund approval email sent to ${userEmail}`);
                }
            } catch (emailErr) {
                console.error('Refund email error:', emailErr);
                // Don't fail the request if email fails
            }
        }

        const updatedRefund = await refundRef.get();
        return res.json({
            success: true,
            message: `Refund ${decisionNormalized}`,
            refund: updatedRefund.data()
        });
    } catch (err) {
        console.error('Approve refund error:', err);
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
        
        // Return user info (excluding password for security)
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

require('./auth-routes')(app, db);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Server listening on http://localhost:${PORT}`);
    });
}

module.exports = app;