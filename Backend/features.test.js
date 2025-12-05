const request = require('supertest');
const app = require('./index');

jest.setTimeout(40000); // Increase timeout

let validToken;
let userId;
const testEmail = `test_auto_${Date.now()}@example.com`;
const testPass = 'password123';

describe('CS308 Project Features - REAL DATA Tests', () => {

    // 1. SETUP: Register -> Login -> Create Data
    beforeAll(async () => {
        // A. Register
        await request(app).post('/auth/register').send({
            name: "Test User",
            email: testEmail,
            password: testPass,
            address: "123 Test St"
        });

        // B. Login
        const loginRes = await request(app).post('/auth/login').send({
            email: testEmail,
            password: testPass
        });

        if (loginRes.statusCode !== 200) {
            throw new Error(`Login failed: ${loginRes.body.message}`);
        }

        validToken = loginRes.body.data.token;
        userId = loginRes.body.data.user_id;

        // C. CREATE ORDER - Use Product 4 (T-Shirt, has 60 stock)
        const checkoutRes = await request(app)
            .post('/checkout')
            .set('Authorization', `Bearer ${validToken}`)
            .send({
                user_id: userId,
                items: [{ product_id: 4, quantity: 1 }]
            });

        if (checkoutRes.statusCode !== 201) {
            console.error("Setup Checkout Failed:", checkoutRes.body);
        }
    });

    // --- REVIEWS ---
    test('1. POST /reviews - Auto-approve review with empty comment', async () => {
        const response = await request(app)
            .post('/reviews')
            .set('Authorization', `Bearer ${validToken}`)
            .send({ product_id: 4, rating: 5, comment: "" });
        expect(response.statusCode).toBe(200);
        expect(response.body.review.status).toBe('approved');
    });

    test('2. POST /reviews - Mark review with text as pending', async () => {
        const response = await request(app)
            .post('/reviews')
            .set('Authorization', `Bearer ${validToken}`)
            .send({ product_id: 4, rating: 4, comment: "Real text." });
        expect(response.statusCode).toBe(200);
        expect(response.body.review.status).toBe('pending');
    });

    test('3. GET /products/:id/reviews - Should fetch reviews', async () => {
        const response = await request(app).get('/products/4/reviews');
        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.reviews)).toBe(true);
    });

    test('4. GET /my-pending-reviews - Success for logged-in user', async () => {
        const response = await request(app)
            .get('/my-pending-reviews')
            .set('Authorization', `Bearer ${validToken}`);
        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.reviews)).toBe(true);
        expect(response.body.reviews.length).toBeGreaterThan(0);
    });

    // --- ORDERS ---
    test('9. GET /users/:uid/orders - Retrieve user orders', async () => {
        const response = await request(app)
            .get(`/users/${userId}/orders`)
            .set('Authorization', `Bearer ${validToken}`);
        expect(response.statusCode).toBe(200);
        expect(Array.isArray(response.body.orders)).toBe(true);
        expect(response.body.orders.length).toBeGreaterThan(0);
    });

    // --- SEARCH ---
    test('6. GET /collections/products - Fetch products', async () => {
        const response = await request(app).get('/collections/products');
        expect(response.statusCode).toBe(200);
        expect(response.body.documents.length).toBeGreaterThan(0);
    });

    // Simple checks for remaining logic
    test('7. GET /collections/products - Verify Fields', async () => {
        const response = await request(app).get('/collections/products');
        expect(response.body.documents[0]).toHaveProperty('name');
    });

    test('8. GET /users/:uid/orders - Fail access without token', async () => {
        const response = await request(app).get(`/users/${userId}/orders`);
        expect(response.statusCode).toBe(401);
    });

    test('5. GET /products/:id/reviews - Verify Sorting', async () => {
        const response = await request(app).get('/products/4/reviews');
        const reviews = response.body.reviews;
        if (reviews.length >= 2) {
            const t1 = new Date(reviews[0].timestamp).getTime();
            const t2 = new Date(reviews[1].timestamp).getTime();
            expect(t1).toBeGreaterThanOrEqual(t2);
        }
    });

    test('10. Verify Order Structure', async () => {
        const response = await request(app)
            .get(`/users/${userId}/orders`)
            .set('Authorization', `Bearer ${validToken}`);
        if (response.body.orders.length > 0) {
            expect(response.body.orders[0]).toHaveProperty('items');
        }
    });
});