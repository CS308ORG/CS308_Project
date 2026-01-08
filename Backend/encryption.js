/**
 * Encryption utility module for handling sensitive data
 * Uses AES-256-GCM encryption for field-level encryption
 */

const crypto = require('crypto');

// Encryption configuration
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16; // For GCM, this is 12-16 bytes
const SALT_LENGTH = 64;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;
const ITERATIONS = 100000;

// Get encryption key from environment or generate one
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'cs308-encryption-key-change-in-production-must-be-32-bytes!!';

// Ensure key is the correct length (32 bytes for AES-256)
let encryptionKey;
if (Buffer.from(ENCRYPTION_KEY).length !== KEY_LENGTH) {
    // Derive a proper key from the provided key using PBKDF2
    const salt = Buffer.from('cs308-salt-fixed-for-key-derivation-must-not-change');
    encryptionKey = crypto.pbkdf2Sync(ENCRYPTION_KEY, salt, ITERATIONS, KEY_LENGTH, 'sha256');
} else {
    encryptionKey = Buffer.from(ENCRYPTION_KEY);
}

/**
 * Encrypts a string value
 * @param {string} text - The text to encrypt
 * @returns {string} - Encrypted text in format: iv:encryptedData:authTag (hex encoded)
 */
function encrypt(text) {
    if (!text || typeof text !== 'string') {
        return text; // Return null/undefined/non-string as-is
    }

    try {
        // Generate a random initialization vector
        const iv = crypto.randomBytes(IV_LENGTH);

        // Create cipher
        const cipher = crypto.createCipheriv(ALGORITHM, encryptionKey, iv);

        // Encrypt the text
        let encrypted = cipher.update(text, 'utf8', 'hex');
        encrypted += cipher.final('hex');

        // Get the authentication tag
        const authTag = cipher.getAuthTag();

        // Return iv:encrypted:authTag (all in hex)
        return `${iv.toString('hex')}:${encrypted}:${authTag.toString('hex')}`;
    } catch (error) {
        console.error('Encryption error:', error);
        throw new Error('Failed to encrypt data');
    }
}

/**
 * Decrypts an encrypted string
 * @param {string} encryptedData - The encrypted data in format: iv:encryptedData:authTag
 * @returns {string} - Decrypted text
 */
function decrypt(encryptedData) {
    if (!encryptedData || typeof encryptedData !== 'string') {
        return encryptedData; // Return null/undefined/non-string as-is
    }

    // Check if the data is actually encrypted (contains colons)
    if (!encryptedData.includes(':')) {
        return encryptedData; // Return unencrypted data as-is (for backward compatibility)
    }

    try {
        // Split the encrypted data
        const parts = encryptedData.split(':');
        if (parts.length !== 3) {
            console.warn('Invalid encrypted data format, returning as-is');
            return encryptedData;
        }

        const iv = Buffer.from(parts[0], 'hex');
        const encrypted = parts[1];
        const authTag = Buffer.from(parts[2], 'hex');

        // Create decipher
        const decipher = crypto.createDecipheriv(ALGORITHM, encryptionKey, iv);
        decipher.setAuthTag(authTag);

        // Decrypt the text
        let decrypted = decipher.update(encrypted, 'hex', 'utf8');
        decrypted += decipher.final('utf8');

        return decrypted;
    } catch (error) {
        console.error('Decryption error:', error);
        throw new Error('Failed to decrypt data');
    }
}

/**
 * Encrypts an object's sensitive fields
 * @param {Object} obj - Object containing data
 * @param {Array<string>} fields - Array of field names to encrypt
 * @returns {Object} - Object with encrypted fields
 */
function encryptFields(obj, fields) {
    if (!obj || typeof obj !== 'object') {
        return obj;
    }

    const encrypted = { ...obj };
    fields.forEach(field => {
        if (encrypted[field]) {
            encrypted[field] = encrypt(encrypted[field]);
        }
    });

    return encrypted;
}

/**
 * Decrypts an object's encrypted fields
 * @param {Object} obj - Object containing encrypted data
 * @param {Array<string>} fields - Array of field names to decrypt
 * @returns {Object} - Object with decrypted fields
 */
function decryptFields(obj, fields) {
    if (!obj || typeof obj !== 'object') {
        return obj;
    }

    const decrypted = { ...obj };
    fields.forEach(field => {
        if (decrypted[field]) {
            decrypted[field] = decrypt(decrypted[field]);
        }
    });

    return decrypted;
}

/**
 * Encrypts multiple objects in an array
 * @param {Array<Object>} arr - Array of objects
 * @param {Array<string>} fields - Fields to encrypt in each object
 * @returns {Array<Object>} - Array with encrypted objects
 */
function encryptArray(arr, fields) {
    if (!Array.isArray(arr)) {
        return arr;
    }
    return arr.map(item => encryptFields(item, fields));
}

/**
 * Decrypts multiple objects in an array
 * @param {Array<Object>} arr - Array of encrypted objects
 * @param {Array<string>} fields - Fields to decrypt in each object
 * @returns {Array<Object>} - Array with decrypted objects
 */
function decryptArray(arr, fields) {
    if (!Array.isArray(arr)) {
        return arr;
    }
    return arr.map(item => decryptFields(item, fields));
}

/**
 * Checks if a value is encrypted
 * @param {string} value - Value to check
 * @returns {boolean} - True if encrypted, false otherwise
 */
function isEncrypted(value) {
    if (!value || typeof value !== 'string') {
        return false;
    }
    // Check if it matches the encrypted format: hex:hex:hex
    const parts = value.split(':');
    if (parts.length !== 3) {
        return false;
    }
    // Check if all parts are valid hex strings
    return parts.every(part => /^[0-9a-f]+$/i.test(part));
}

module.exports = {
    encrypt,
    decrypt,
    encryptFields,
    decryptFields,
    encryptArray,
    decryptArray,
    isEncrypted
};
