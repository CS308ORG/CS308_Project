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
  });

  describe('POST /auth/login - Login Tests', () => {
    test('Test 3: Should successfully login with correct credentials', testLoginSuccess);
    test('Test 4: Should fail login with incorrect password', testLoginWrongPassword);
  });
});

module.exports = app;
