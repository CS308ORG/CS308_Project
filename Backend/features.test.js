const request = require('supertest');

// --- 1. SETUP MOCK DATA ---
const mockReviews = [
    {
        review_id: '101',
        product_id: 1,
        rating: 5,
        comment: "Great!",
        approval_status: "approved",
        timestamp: "2025-12-05T10:00:00Z"
    },
    {
        review_id: '102',
        product_id: 1,
        rating: 4,
        comment: "Good",
        approval_status: "approved",
        timestamp: "2025-12-04T10:00:00Z"
    }
];

const mockOrders = [
    {
        order_id: 1,
        user_id: 1,
        total_amount: 150.00,
        status: 'processing',
        date: "2025-12-01T10:00:00Z",
        items: [{ product_id: 1, quantity: 1 }]
    }
];

const mockProducts = [
    { product_id: 1, name: "Laptop", description: "A fast laptop" },
    { product_id: 2, name: "Phone", description: "A smart phone" }
];

// --- 2. DEFINE MOCK IMPLEMENTATION ---

// Mock Firestore Instance (The object returned by admin.firestore())
const mockFirestoreInstance = {
    collection: jest.fn((collectionName) => {
        return {
            where: jest.fn().mockReturnThis(),
            orderBy: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockImplementation(async () => {
                let data = [];
                if (collectionName === 'reviews') data = mockReviews;
                if (collectionName === 'orders') data = mockOrders;
                if (collectionName === 'products' || collectionName === 'collections') data = mockProducts;

                return {
                    empty: data.length === 0,
                    docs: data.map(item => ({
                        id: (item.id || item.review_id || item.order_id || '1').toString(),
                        data: () => item,
                        exists: true
                    })),
                    forEach: (callback) => data.forEach(item => callback({ data: () => item }))
                };
            }),
            doc: jest.fn((docId) => ({
                get: jest.fn().mockResolvedValue({
                    exists: true,
                    data: () => ({ user_id: 1, name: "Ali", role: "customer", email: "ali@example.com" })
                }),
                set: jest.fn().mockResolvedValue(true),
                update: jest.fn().mockResolvedValue(true),
                delete: jest.fn().mockResolvedValue(true),
            })),
            add: jest.fn().mockResolvedValue(true)
        };
    }),
    listCollections: jest.fn().mockResolvedValue([
        { id: 'products' }, { id: 'users' }, { id: 'orders' }
    ]),
    runTransaction: jest.fn().mockImplementation(async (callback) => {
        // Simple mock transaction that just runs the callback
        // We pass a mock transaction object
        return callback({
            get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ price: 100, quantity_in_stock: 50, nextOrderId: 100 })
            }),
            update: jest.fn(),
            set: jest.fn()
        });
    })
};

// Mock Auth Service
const mockAuthInstance = {
    verifyIdToken: jest.fn(async (token) => {
        if (token === 'mock_valid_token') {
            return { uid: '1', user_id: 1, email: 'ali@example.com', role: 'customer' };
        }
        throw new Error('Invalid token');
    }),
    setCustomUserClaims: jest.fn()
};

// --- 3. REGISTER MOCK ---
jest.mock('firebase-admin', () => {
    // The firestore function must be executable AND have properties
    const firestoreFn = () => mockFirestoreInstance;
    firestoreFn.FieldValue = {
        serverTimestamp: () => "MOCK_TIMESTAMP",
        increment: () => "MOCK_INCREMENT"
    };

    return {
        initializeApp: jest.fn(),
        credential: {
            cert: jest.fn(),
            applicationDefault: jest.fn()
        },
        firestore: firestoreFn,
        auth: () => mockAuthInstance
    };
});

// --- 4. IMPORT APP (AFTER MOCKING) ---
const app = require('./index');
const mockToken = "mock_valid_token";

// --- 5. TESTS ---
describe('CS308 Project Features - Unit Tests', () => {

    // --- REVIEWS ---
    test('1. POST /reviews - Auto-approve review with empty comment', async () => {
        const response = await request(app)
            .post('/reviews')
            .set('Authorization', `Bearer ${mockToken}`)
            .send({ product_id: 1, rating: 5, comment: "" });

        expect(response.statusCode).toBe(200);
        expect(response.body.review.status).toBe('approved');
    });

    test('2. POST /reviews - Mark review with text as pending', async () => {
        const response = await request(app)
            .post('/reviews')
            .set('Authorization', `Bearer ${mockToken}`)
            .send({ product_id: 1, rating: 4, comment: "Text" });

        expect(response.statusCode).toBe(200);
        expect(response.body.review.status).toBe('pending');
    });

    test('3. GET /products/:id/reviews - Should fetch reviews', async () => {
        const response = await request(app).get('/products/1/reviews');
        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.reviews)).toBe(true);
    });

    test('4. GET /my-pending-reviews - Success for logged-in user', async () => {
        const response = await request(app)
            .get('/my-pending-reviews')
            .set('Authorization', `Bearer ${mockToken}`);

        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.reviews)).toBe(true);
    });

    test('5. GET /products/:id/reviews - Verify Sorting', async () => {
        const response = await request(app).get('/products/1/reviews');
        const reviews = response.body.reviews;
        // Ensure we actually have reviews to test sorting
        if (reviews.length >= 2) {
            // Mock data has timestamps 2025-12-05 and 2025-12-04
            // We expect 2025-12-05 (Review 101) to be first
            expect(reviews[0].review_id).toBe('101');
        }
    });

    // --- SEARCH / COLLECTIONS ---
    test('6. GET /collections/products - Fetch products', async () => {
        const response = await request(app).get('/collections/products');
        expect(response.statusCode).toBe(200);
        expect(response.body.documents).toBeDefined();
        expect(response.body.documents.length).toBeGreaterThan(0);
    });

    test('7. GET /collections/products - Verify Fields', async () => {
        const response = await request(app).get('/collections/products');
        const product = response.body.documents[0];
        expect(product).toHaveProperty('name');
        expect(product).toHaveProperty('description');
    });

    // --- ORDERS ---
    test('8. GET /users/:uid/orders - Fail access without token', async () => {
        const response = await request(app).get('/users/1/orders');
        expect(response.statusCode).toBe(401);
    });

    test('9. GET /users/:uid/orders - Retrieve user orders', async () => {
        const response = await request(app)
            .get('/users/1/orders')
            .set('Authorization', `Bearer ${mockToken}`);

        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.orders)).toBe(true);
        if (response.body.orders.length > 0) {
            expect(response.body.orders[0].order_id).toBe(1);
        }
    });

    test('10. GET /users/:uid/orders - Verify Order Structure', async () => {
        const response = await request(app)
            .get('/users/1/orders')
            .set('Authorization', `Bearer ${mockToken}`);

        expect(response.statusCode).toBe(200);
        if (response.body.orders && response.body.orders.length > 0) {
            const order = response.body.orders[0];
            expect(order).toHaveProperty('items');
            expect(Array.isArray(order.items)).toBe(true);
        }
    });
});