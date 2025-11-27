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
        const snapshot = await firestore.collection(name).limit(20).get();
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
        endpoints: ['/health', '/collections', '/collections/:name', '/login', '/register', '/roles', '/users/:id/role', '/users/:uid/orders']
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

        if (userData.password !== password) {
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

        const newUser = {
            user_id: newUserId,
            email: email,
            password: password,
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
// Returns full order history with nested items and product names
app.get('/users/:uid/orders', authenticate, async (req, res) => {
    const uid = req.params.uid;
    // Security check: ensure requesting user matches target UID (or is admin)
    if (req.user.uid !== uid && req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized access to order history' });
    }

    // Handle integer IDs (Seed Data) vs String IDs (Real Data)
    const uidQuery = /^\d+$/.test(uid) ? parseInt(uid) : uid;

    try {
        // 1. Get Orders
        const ordersSnapshot = await db.collection('orders').where('user_id', '==', uidQuery).get();
        const orders = [];

        for (const orderDoc of ordersSnapshot.docs) {
            const orderData = orderDoc.data();
            const orderId = orderData.order_id;

            // 2. Get Items for this Order
            const itemsSnapshot = await db.collection('order_items').where('order_id', '==', orderId).get();

            const items = [];
            for (const itemDoc of itemsSnapshot.docs) {
                const itemData = itemDoc.data();

                // 3. Get Product Details (Name, Image, etc.) for each Item
                let productDetails = { name: "Unknown Product" };
                try {
                    // Seed product IDs are integers, ensure string for doc lookup if needed
                    const productDoc = await db.collection('products').doc(String(itemData.product_id)).get();
                    if (productDoc.exists) {
                        productDetails = productDoc.data();
                    }
                } catch (e) {
                    console.error("Product fetch error", e);
                }

                // Merge product details into item data
                items.push({
                    ...productDetails,
                    ...itemData,
                    name: productDetails.name // Ensure name comes from product if available
                });
            }

            // 4. Construct Order Object
            orders.push({
                ...orderData,
                items: items,
                // Default date to now if missing (Seed data lacks dates)
                date: orderData.date || new Date().toISOString()
            });
        }

        return res.json({ orders });
    } catch (err) {
        console.error(err);
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
            .where('status', '==', 'approved')
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
            .where('status', '==', 'pending')
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

    // Force status: text = pending, no text = approved
    const hasText = comment && comment.trim().length > 0;
    const status = hasText ? 'pending' : 'approved';

    const userId = req.user.uid;

    // Handle product ID type consistency
    const pidInt = parseInt(product_id);
    const finalProductId = isNaN(pidInt) ? product_id : pidInt;

    try {
        // Fetch user name for display purposes
        const userDoc = await db.collection('users').doc(userId).get();
        const userName = userDoc.exists ? (userDoc.data().name || "Customer") : "Customer";

        const newReview = {
            review_id: Date.now().toString(), // Simple ID generation
            user_id: userId,
            author_name: userName, // Saved for display
            product_id: finalProductId,
            rating: Number(rating),
            comment: comment || "",
            status: status,
            timestamp: new Date().toISOString()
        };
        await db.collection('reviews').doc(newReview.review_id).set(newReview);
        return res.json({ success: true, review: newReview });

    } catch (err) {
        return res.status(500).json({ error: err.message });
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
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
});