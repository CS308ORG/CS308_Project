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
require('./auth-routes')(app, db);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Server listening on http://localhost:${PORT}`);
    });
}

module.exports = app;