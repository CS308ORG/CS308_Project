/**
 * Unit Tests for Authentication Endpoints (Sign Up & Login)
 * Feature: User Registration and Authentication
 * Developed by: İrem Ulusal
 * 
 * Tests the REAL endpoints from auth-routes.js
 * Only Firebase database is mocked
 */

const request = require('supertest');
const express = require('express');
const cors = require('cors');

// Create Express app (same as real app)
const app = express();
app.use(cors());
app.use(express.json());

// Mock Firebase Firestore
const mockFirestore = {
  users: new Map(),
  signup_logs: [],
  login_logs: [],
  nextUserId: 1,
  
  collection: function(collectionName) {
    const self = this;
    
    return {
      doc: function(docId) {
        return {
          get: async function() {
            if (collectionName === 'users') {
              const user = self.users.get(docId);
              return {
                exists: !!user,
                data: () => user || null,
                id: docId
              };
            }
            return { exists: false, data: () => null };
          },
          set: async function(data) {
            if (collectionName === 'users') {
              self.users.set(docId, data);
            }
          }
        };
      },
      where: function(field, operator, value) {
        return {
          limit: function(n) {
            return {
              get: async function() {
                if (collectionName === 'users' && field === 'email') {
                  const users = Array.from(self.users.values())
                    .filter(u => u.email === value)
                    .slice(0, n);
                  return {
                    empty: users.length === 0,
                    docs: users.map((u, idx) => ({
                      id: String(u.user_id),
                      data: () => u
                    }))
                  };
                }
                return { empty: true, docs: [] };
              }
            };
          },
          get: async function() {
            if (collectionName === 'users' && field === 'email') {
              const users = Array.from(self.users.values())
                .filter(u => u.email === value);
              return {
                empty: users.length === 0,
                docs: users.map((u) => ({
                  id: String(u.user_id),
                  data: () => u
                }))
              };
            }
            return { empty: true, docs: [] };
          }
        };
      },
      orderBy: function(field, direction) {
        return {
          limit: function(n) {
            return {
              get: async function() {
                if (collectionName === 'users' && field === 'user_id') {
                  const users = Array.from(self.users.values())
                    .sort((a, b) => direction === 'desc' ? b.user_id - a.user_id : a.user_id - b.user_id)
                    .slice(0, n);
                  return {
                    empty: users.length === 0,
                    docs: users.map((u) => ({
                      id: String(u.user_id),
                      data: () => u
                    }))
                  };
                }
                return { empty: true, docs: [] };
              }
            };
          }
        };
      },
      add: async function(data) {
        if (collectionName === 'signup_logs') {
          self.signup_logs.push(data);
        } else if (collectionName === 'login_logs') {
          self.login_logs.push(data);
        }
      }
    };
  }
};

// Load REAL auth routes with mocked database
require('./auth-routes')(app, mockFirestore);

// ============================================
// TEST FUNCTIONS - Each test is a separate function
// ============================================

/**
 * Test Function 1: Successful user registration
 */
async function testRegisterSuccess() {
  const response = await request(app)
    .post('/auth/register')
    .send({
      email: 'irem@example.com',
      password: 'password123',
      name: 'İrem Ulusal',
      address: 'Istanbul, TR'
    });

  expect(response.statusCode).toBe(201);
  expect(response.body.success).toBe(true);
  expect(response.body.message).toBe('Kullanıcı başarıyla oluşturuldu');
  expect(response.body.data.email).toBe('irem@example.com');
  expect(response.body.data.name).toBe('İrem Ulusal');
  expect(response.body.data).toHaveProperty('token');
  expect(response.body.data).not.toHaveProperty('password');
}

/**
 * Test Function 2: Registration with duplicate email
 */
async function testRegisterDuplicate() {
  // First registration
  await request(app)
    .post('/auth/register')
    .send({
      email: 'duplicate@example.com',
      password: 'password123',
      name: 'First User'
    });

  // Second registration with same email
  const response = await request(app)
    .post('/auth/register')
    .send({
      email: 'duplicate@example.com',
      password: 'password456',
      name: 'Second User'
    });

  expect(response.statusCode).toBe(400);
  expect(response.body.success).toBe(false);
  expect(response.body.error).toBe('Email exists');
  expect(response.body.message).toBe('Bu email adresi zaten kullanılıyor');
}

/**
 * Test Function 3: Successful login with correct credentials
 */
async function testLoginSuccess() {
  // Setup: Register a user first
  await request(app)
    .post('/auth/register')
    .send({
      email: 'testuser@example.com',
      password: 'correctpassword',
      name: 'Test User'
    });

  const response = await request(app)
    .post('/auth/login')
    .send({
      email: 'testuser@example.com',
      password: 'correctpassword'
    });

  expect(response.statusCode).toBe(200);
  expect(response.body.success).toBe(true);
  expect(response.body.message).toBe('Giriş başarılı');
  expect(response.body.data.email).toBe('testuser@example.com');
  expect(response.body.data).toHaveProperty('token');
  expect(response.body.data).not.toHaveProperty('password');
}

/**
 * Test Function 4: Login with incorrect password
 */
async function testLoginWrongPassword() {
  // Setup: Register a user first
  await request(app)
    .post('/auth/register')
    .send({
      email: 'testuser@example.com',
      password: 'correctpassword',
      name: 'Test User'
    });

  const response = await request(app)
    .post('/auth/login')
    .send({
      email: 'testuser@example.com',
      password: 'wrongpassword'
    });

  expect(response.statusCode).toBe(401);
  expect(response.body.success).toBe(false);
  expect(response.body.error).toBe('Invalid credentials');
  expect(response.body.message).toBe('Email veya şifre hatalı');
}

/**
 * Test Function 5: Verify user exists in database after registration
 */
async function testRegisterDatabaseCheck() {
  await request(app)
    .post('/auth/register')
    .send({
      email: 'dbcheck@example.com',
      password: 'password123',
      name: 'DB Check User',
      address: 'Istanbul'
    });

  // Manually check the mock database
  let userFound = false;
  for (let user of mockFirestore.users.values()) {
    if (user.email === 'dbcheck@example.com') {
      userFound = true;
      break;
    }
  }
  expect(userFound).toBe(true);
}

/**
 * Test Function 6: Verify signup log is created
 */
async function testSignupLogCreation() {
  await request(app)
    .post('/auth/register')
    .send({
      email: 'logcheck@example.com',
      password: 'password123',
      name: 'Log User',
      address: 'Istanbul'
    });

  // Check signup_logs collection in mock db
  const log = mockFirestore.signup_logs.find(l => l.email === 'logcheck@example.com');
  expect(log).toBeDefined();
  expect(log.method).toBe('email_password');
}

/**
 * Test Function 7: Verify default role assignment
 */
async function testDefaultRoleAssignment() {
  const response = await request(app)
    .post('/auth/register')
    .send({
      email: 'rolecheck@example.com',
      password: 'password123',
      name: 'Role User',
      address: 'Istanbul'
    });

  expect(response.body.data.role).toBe('customer');
  
  // Verify in DB as well
  const user = Array.from(mockFirestore.users.values()).find(u => u.email === 'rolecheck@example.com');
  expect(user.role).toBe('customer');
}

/**
 * Test Function 8: Verify login log is created upon success
 */
async function testLoginLogCreation() {
  // Register
  await request(app)
    .post('/auth/register')
    .send({
      email: 'loginlog@example.com',
      password: 'password123',
      name: 'Login Log User'
    });

  // Login
  await request(app)
    .post('/auth/login')
    .send({
      email: 'loginlog@example.com',
      password: 'password123'
    });

  // Check login_logs
  const log = mockFirestore.login_logs.find(l => l.email === 'loginlog@example.com');
  expect(log).toBeDefined();
  expect(log.success).toBe(true);
}

/**
 * Test Function 9: Login failure for non-existent user
 */
async function testNonExistentUserLogin() {
  const response = await request(app)
    .post('/auth/login')
    .send({
      email: 'nobody@example.com',
      password: 'anypassword'
    });

  expect(response.statusCode).toBe(404);
  expect(response.body.success).toBe(false);
}

// ============================================
// TEST SUITE
// ============================================

describe('Authentication API Tests - Real Endpoints', () => {
  
  // Reset mock database before each test
  beforeEach(() => {
    mockFirestore.users.clear();
    mockFirestore.signup_logs = [];
    mockFirestore.login_logs = [];
    mockFirestore.nextUserId = 1;
  });

  describe('POST /auth/register - Sign Up Tests', () => {
    test('Test 1: Should successfully register a new user with valid data', testRegisterSuccess);
    test('Test 2: Should fail registration with duplicate email', testRegisterDuplicate);
    test('Test 5: Should verify user exists in database', testRegisterDatabaseCheck);
    test('Test 6: Should create a signup log entry', testSignupLogCreation);
    test('Test 7: Should assign default role "customer"', testDefaultRoleAssignment);
  });

  describe('POST /auth/login - Login Tests', () => {
    test('Test 3: Should successfully login with correct credentials', testLoginSuccess);
    test('Test 4: Should fail login with incorrect password', testLoginWrongPassword);
    test('Test 8: Should create a login log entry on success', testLoginLogCreation);
    test('Test 9: Should fail login for non-existent user', testNonExistentUserLogin);
  });
});

module.exports = app;
