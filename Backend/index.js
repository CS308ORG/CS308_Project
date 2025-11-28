const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// ============================================
// FIREBASE INITIALIZATION
// ============================================

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH || './my-firebase-sa.json';

try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase initialized successfully!');
} catch (error) {
    console.error('❌ Firebase initialization failed:', error.message);
    process.exit(1);
}

const db = admin.firestore();
const app = express();

// ============================================
// MIDDLEWARE
// ============================================

app.use(cors());
app.use(express.json());

// ============================================
// CONFIG
// ============================================

const JWT_SECRET = process.env.JWT_SECRET || 'cs308-secret-key-change-in-production';
const JWT_EXPIRES_IN = '24h';
const SALT_ROUNDS = 10;

// ============================================
// HELPER FUNCTIONS
// ============================================

async function getNextUserId() {
    const snapshot = await db.collection('users')
        .orderBy('user_id', 'desc')
        .limit(1)
        .get();
    
    if (snapshot.empty) {
        return 1;
    }
    
    return snapshot.docs[0].data().user_id + 1;
}

async function findUserByEmail(email) {
    const snapshot = await db.collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();
    
    if (snapshot.empty) {
        return null;
    }
    
    return { id: snapshot.docs[0].id, ...snapshot.docs[0].data() };
}

async function findUserById(userId) {
    const userDoc = await db.collection('users').doc(String(userId)).get();
    
    if (!userDoc.exists) {
        return null;
    }
    
    return { id: userDoc.id, ...userDoc.data() };
}

// ============================================
// AUTH MIDDLEWARE - Token Doğrulama
// ============================================

const authenticateToken = (req, res, next) => {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ 
            success: false,
            error: 'Unauthorized', 
            message: 'Token gerekli. Header: Authorization: Bearer <token>' 
        });
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        console.error('Token doğrulama hatası:', error.message);
        return res.status(401).json({ 
            success: false,
            error: 'Invalid token', 
            message: 'Geçersiz veya süresi dolmuş token' 
        });
    }
};

// ============================================
// AUTH ENDPOINTS
// ============================================

/**
 * POST /auth/register
 * Yeni kullanıcı kaydı
 * Body: { name, email, password, address }
 */
app.post('/auth/register', async (req, res) => {
    const { name, email, password, address } = req.body;
    
    // Validasyon
    if (!name || !email || !password) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Ad, email ve şifre zorunludur'
        });
    }
    
    // Email formatı kontrolü
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Geçerli bir email adresi giriniz'
        });
    }
    
    // Şifre uzunluğu kontrolü
    if (password.length < 6) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Şifre en az 6 karakter olmalıdır'
        });
    }
    
    try {
        // Email zaten kullanılıyor mu kontrol et
        const existingUser = await findUserByEmail(email);
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: 'Email exists',
                message: 'Bu email adresi zaten kullanılıyor'
            });
        }
        
        // Şifreyi hashle
        const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
        
        // Yeni user_id al
        const userId = await getNextUserId();
        
        // Yeni kullanıcı objesi oluştur
        const newUser = {
            user_id: userId,
            name: name,
            email: email,
            password: hashedPassword,
            address: address || '',
            role: 'customer',
            created_at: new Date().toISOString()
        };
        
        // Firestore'a kaydet
        await db.collection('users').doc(String(userId)).set(newUser);
        
        // Signup log'u kaydet
        const signupLog = {
            signup_id: Date.now(),
            user_id: userId,
            email: email,
            timestamp: new Date().toISOString(),
            method: 'email_password'
        };
        await db.collection('signup_logs').add(signupLog);
        
        // JWT token oluştur
        const token = jwt.sign(
            { 
                user_id: userId, 
                email: email, 
                role: 'customer',
                name: name
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        
        return res.status(201).json({
            success: true,
            message: 'Kullanıcı başarıyla oluşturuldu',
            data: {
                user_id: userId,
                name: name,
                email: email,
                role: 'customer',
                address: address || '',
                token: token
            }
        });
        
    } catch (error) {
        console.error('Register hatası:', error);
        return res.status(500).json({
            success: false,
            error: 'Server error',
            message: 'Kayıt işlemi başarısız oldu'
        });
    }
});

/**
 * POST /auth/login
 * Kullanıcı girişi
 * Body: { email, password }
 */
app.post('/auth/login', async (req, res) => {
    const { email, password } = req.body;
    
    // Validasyon
    if (!email || !password) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Email ve şifre zorunludur'
        });
    }
    
    try {
        // Kullanıcıyı email ile bul
        const user = await findUserByEmail(email);
        
        if (!user) {
            // Login log'u kaydet (başarısız)
            const loginLog = {
                login_id: Date.now(),
                user_id: null,
                email: email,
                timestamp: new Date().toISOString(),
                success: false,
                ip_address: req.ip || 'unknown'
            };
            await db.collection('login_logs').add(loginLog);
            
            return res.status(401).json({
                success: false,
                error: 'Invalid credentials',
                message: 'Email veya şifre hatalı'
            });
        }
        
        // Şifreyi kontrol et
        const isPasswordValid = await bcrypt.compare(password, user.password);
        
        if (!isPasswordValid) {
            // Login log'u kaydet (başarısız)
            const loginLog = {
                login_id: Date.now(),
                user_id: user.user_id,
                email: email,
                timestamp: new Date().toISOString(),
                success: false,
                ip_address: req.ip || 'unknown'
            };
            await db.collection('login_logs').add(loginLog);
            
            return res.status(401).json({
                success: false,
                error: 'Invalid credentials',
                message: 'Email veya şifre hatalı'
            });
        }
        
        // Login log'u kaydet (başarılı)
        const loginLog = {
            login_id: Date.now(),
            user_id: user.user_id,
            email: email,
            timestamp: new Date().toISOString(),
            success: true,
            ip_address: req.ip || 'unknown'
        };
        await db.collection('login_logs').add(loginLog);
        
        // JWT token oluştur
        const token = jwt.sign(
            { 
                user_id: user.user_id, 
                email: user.email, 
                role: user.role,
                name: user.name
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        
        return res.status(200).json({
            success: true,
            message: 'Giriş başarılı',
            data: {
                user_id: user.user_id,
                name: user.name,
                email: user.email,
                role: user.role,
                address: user.address,
                token: token
            }
        });
        
    } catch (error) {
        console.error('Login hatası:', error);
        return res.status(500).json({
            success: false,
            error: 'Server error',
            message: 'Giriş işlemi başarısız oldu'
        });
    }
});

/**
 * GET /auth/me
 * Mevcut kullanıcı bilgilerini getir (Korunan route)
 * Header: Authorization: Bearer <token>
 */
app.get('/auth/me', authenticateToken, async (req, res) => {
    try {
        const { user_id } = req.user;
        
        const user = await findUserById(user_id);
        
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'User not found',
                message: 'Kullanıcı bulunamadı'
            });
        }
        
        return res.status(200).json({
            success: true,
            data: {
                user_id: user.user_id,
                name: user.name,
                email: user.email,
                address: user.address,
                role: user.role,
                created_at: user.created_at
            }
        });
        
    } catch (error) {
        console.error('Kullanıcı bilgisi hatası:', error);
        return res.status(500).json({
            success: false,
            error: 'Server error',
            message: 'Kullanıcı bilgileri alınamadı'
        });
    }
});

/**
 * PUT /auth/update-profile
 * Kullanıcı profilini güncelle (Korunan route)
 * Header: Authorization: Bearer <token>
 * Body: { name, address }
 */
app.put('/auth/update-profile', authenticateToken, async (req, res) => {
    const { name, address } = req.body;
    const { user_id } = req.user;
    
    if (!name && !address) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'En az bir alan güncellenmelidir (name veya address)'
        });
    }
    
    try {
        const updateData = {};
        if (name) updateData.name = name;
        if (address) updateData.address = address;
        updateData.updated_at = new Date().toISOString();
        
        await db.collection('users').doc(String(user_id)).update(updateData);
        
        return res.status(200).json({
            success: true,
            message: 'Profil güncellendi',
            data: updateData
        });
        
    } catch (error) {
        console.error('Profil güncelleme hatası:', error);
        return res.status(500).json({
            success: false,
            error: 'Update failed',
            message: 'Profil güncellenemedi'
        });
    }
});

/**
 * POST /auth/change-password
 * Şifre değiştir (Korunan route)
 * Header: Authorization: Bearer <token>
 * Body: { currentPassword, newPassword }
 */
app.post('/auth/change-password', authenticateToken, async (req, res) => {
    const { currentPassword, newPassword } = req.body;
    const { user_id } = req.user;
    
    if (!currentPassword || !newPassword) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Mevcut şifre ve yeni şifre zorunludur'
        });
    }
    
    if (newPassword.length < 6) {
        return res.status(400).json({
            success: false,
            error: 'Validation error',
            message: 'Yeni şifre en az 6 karakter olmalıdır'
        });
    }
    
    try {
        const user = await findUserById(user_id);
        
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'User not found',
                message: 'Kullanıcı bulunamadı'
            });
        }
        
        // Mevcut şifreyi kontrol et
        const isPasswordValid = await bcrypt.compare(currentPassword, user.password);
        
        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                error: 'Invalid password',
                message: 'Mevcut şifre hatalı'
            });
        }
        
        // Yeni şifreyi hashle ve güncelle
        const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);
        
        await db.collection('users').doc(String(user_id)).update({
            password: hashedPassword,
            updated_at: new Date().toISOString()
        });
        
        return res.status(200).json({
            success: true,
            message: 'Şifre başarıyla değiştirildi'
        });
        
    } catch (error) {
        console.error('Şifre değiştirme hatası:', error);
        return res.status(500).json({
            success: false,
            error: 'Password change failed',
            message: 'Şifre değiştirilemedi'
        });
    }
});

// ============================================
// DATABASE ENDPOINTS
// ============================================

app.get('/health', (req, res) => {
    return res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        mode: 'Firebase Firestore connected',
        project_id: 'cs308db'
    });
});

app.get('/collections', async (req, res) => {
    try {
        const collections = await db.listCollections();
        const names = collections.map((c) => c.id);
        return res.json({ success: true, collections: names });
    } catch (err) {
        console.error('Failed to list collections:', err);
        return res.status(500).json({ success: false, error: 'Failed to list collections' });
    }
});

app.get('/collections/:name', async (req, res) => {
    const { name } = req.params;
    try {
        const snapshot = await db.collection(name).limit(20).get();
        const documents = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        return res.json({ success: true, collection: name, count: documents.length, documents });
    } catch (err) {
        console.error(`Failed to read collection ${name}:`, err);
        return res.status(500).json({ success: false, error: `Failed to read collection ${name}` });
    }
});

app.get('/', (req, res) => {
    return res.json({
        message: 'CS308 Backend API - Firebase Firestore Mode',
        version: '1.0.0',
        project_id: 'cs308db',
        endpoints: {
            auth: {
                'POST /auth/register': 'Yeni kullanıcı kaydı (name, email, password, address?)',
                'POST /auth/login': 'Kullanıcı girişi (email, password)',
                'GET /auth/me': 'Mevcut kullanıcı bilgileri [TOKEN GEREKLİ]',
                'PUT /auth/update-profile': 'Profil güncelleme (name?, address?) [TOKEN GEREKLİ]',
                'POST /auth/change-password': 'Şifre değiştirme (currentPassword, newPassword) [TOKEN GEREKLİ]'
            },
            database: {
                'GET /collections': 'Tüm koleksiyonları listele',
                'GET /collections/:name': 'Koleksiyondan veri oku'
            },
            system: {
                'GET /health': 'Sistem durumu kontrolü'
            }
        }
    });
});

// ============================================
// ERROR HANDLING
// ============================================

app.use((req, res) => {
    return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: `${req.method} ${req.path} bulunamadı`
    });
});

app.use((err, req, res, next) => {
    console.error('Server error:', err);
    return res.status(500).json({
        success: false,
        error: 'Internal Server Error',
        message: 'Beklenmeyen bir hata oluştu'
    });
});

// ============================================
// START SERVER
// ============================================

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server listening on http://localhost:${PORT}`);
    console.log(`📚 API documentation: http://localhost:${PORT}/`);
    console.log(`🔥 Firebase Firestore: cs308db`);
});
