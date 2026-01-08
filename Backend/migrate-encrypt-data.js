/**
 * Data Migration Script - Encrypt Existing Sensitive Data
 *
 * This script encrypts all existing sensitive data in the database:
 * - Users: email, address, taxID
 * - Orders: delivery_address
 * - Refunds: customer_email, reason
 * - Login logs: email, ip_address
 * - Signup logs: email
 *
 * IMPORTANT: Run this script ONCE after deploying encryption changes
 * Make sure to backup your database before running this script!
 */

require('dotenv').config();
const admin = require('firebase-admin');
const { encrypt, isEncrypted } = require('./encryption');

// Initialize Firebase Admin
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

// Migration statistics
const stats = {
    users: { total: 0, encrypted: 0, skipped: 0, errors: 0 },
    orders: { total: 0, encrypted: 0, skipped: 0, errors: 0 },
    refunds: { total: 0, encrypted: 0, skipped: 0, errors: 0 },
    login_logs: { total: 0, encrypted: 0, skipped: 0, errors: 0 },
    signup_logs: { total: 0, encrypted: 0, skipped: 0, errors: 0 }
};

/**
 * Migrate users collection
 */
async function migrateUsers() {
    console.log('\n📧 Migrating users collection...');
    const snapshot = await db.collection('users').get();
    stats.users.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const updates = {};
            let needsUpdate = false;

            // Encrypt email if not already encrypted
            if (data.email && !isEncrypted(data.email)) {
                updates.email = encrypt(data.email);
                needsUpdate = true;
            }

            // Encrypt address if not already encrypted
            if (data.address && !isEncrypted(data.address)) {
                updates.address = encrypt(data.address);
                needsUpdate = true;
            }

            // Encrypt taxID if exists and not already encrypted
            if (data.taxID && !isEncrypted(data.taxID)) {
                updates.taxID = encrypt(data.taxID);
                needsUpdate = true;
            }

            if (needsUpdate) {
                await doc.ref.update(updates);
                stats.users.encrypted++;
                console.log(`  ✓ Encrypted user ${doc.id} (${data.name || 'No name'})`);
            } else {
                stats.users.skipped++;
            }
        } catch (error) {
            stats.users.errors++;
            console.error(`  ✗ Error encrypting user ${doc.id}:`, error.message);
        }
    }
}

/**
 * Migrate orders collection
 */
async function migrateOrders() {
    console.log('\n📦 Migrating orders collection...');
    const snapshot = await db.collection('orders').get();
    stats.orders.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const updates = {};
            let needsUpdate = false;

            // Encrypt delivery_address if not already encrypted
            if (data.delivery_address && !isEncrypted(data.delivery_address)) {
                updates.delivery_address = encrypt(data.delivery_address);
                needsUpdate = true;
            }

            // Also check deliveryAddress (alternative field name)
            if (data.deliveryAddress && !isEncrypted(data.deliveryAddress)) {
                updates.deliveryAddress = encrypt(data.deliveryAddress);
                needsUpdate = true;
            }

            if (needsUpdate) {
                await doc.ref.update(updates);
                stats.orders.encrypted++;
                console.log(`  ✓ Encrypted order ${doc.id}`);
            } else {
                stats.orders.skipped++;
            }
        } catch (error) {
            stats.orders.errors++;
            console.error(`  ✗ Error encrypting order ${doc.id}:`, error.message);
        }
    }
}

/**
 * Migrate refunds collection
 */
async function migrateRefunds() {
    console.log('\n💰 Migrating refunds collection...');
    const snapshot = await db.collection('refunds').get();
    stats.refunds.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const updates = {};
            let needsUpdate = false;

            // Encrypt customer_email if not already encrypted
            if (data.customer_email && !isEncrypted(data.customer_email)) {
                updates.customer_email = encrypt(data.customer_email);
                needsUpdate = true;
            }

            // Encrypt reason if not already encrypted
            if (data.reason && !isEncrypted(data.reason)) {
                updates.reason = encrypt(data.reason);
                needsUpdate = true;
            }

            if (needsUpdate) {
                await doc.ref.update(updates);
                stats.refunds.encrypted++;
                console.log(`  ✓ Encrypted refund ${doc.id}`);
            } else {
                stats.refunds.skipped++;
            }
        } catch (error) {
            stats.refunds.errors++;
            console.error(`  ✗ Error encrypting refund ${doc.id}:`, error.message);
        }
    }
}

/**
 * Migrate login_logs collection
 */
async function migrateLoginLogs() {
    console.log('\n🔐 Migrating login_logs collection...');
    const snapshot = await db.collection('login_logs').get();
    stats.login_logs.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const updates = {};
            let needsUpdate = false;

            // Encrypt email if not already encrypted
            if (data.email && !isEncrypted(data.email)) {
                updates.email = encrypt(data.email);
                needsUpdate = true;
            }

            // Encrypt ip_address if not already encrypted
            if (data.ip_address && !isEncrypted(data.ip_address)) {
                updates.ip_address = encrypt(data.ip_address);
                needsUpdate = true;
            }

            if (needsUpdate) {
                await doc.ref.update(updates);
                stats.login_logs.encrypted++;
                if (stats.login_logs.encrypted % 10 === 0) {
                    console.log(`  ✓ Encrypted ${stats.login_logs.encrypted} login logs...`);
                }
            } else {
                stats.login_logs.skipped++;
            }
        } catch (error) {
            stats.login_logs.errors++;
            console.error(`  ✗ Error encrypting login log ${doc.id}:`, error.message);
        }
    }
}

/**
 * Migrate signup_logs collection
 */
async function migrateSignupLogs() {
    console.log('\n📝 Migrating signup_logs collection...');
    const snapshot = await db.collection('signup_logs').get();
    stats.signup_logs.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const updates = {};
            let needsUpdate = false;

            // Encrypt email if not already encrypted
            if (data.email && !isEncrypted(data.email)) {
                updates.email = encrypt(data.email);
                needsUpdate = true;
            }

            if (needsUpdate) {
                await doc.ref.update(updates);
                stats.signup_logs.encrypted++;
                console.log(`  ✓ Encrypted signup log ${doc.id}`);
            } else {
                stats.signup_logs.skipped++;
            }
        } catch (error) {
            stats.signup_logs.errors++;
            console.error(`  ✗ Error encrypting signup log ${doc.id}:`, error.message);
        }
    }
}

/**
 * Print migration statistics
 */
function printStats() {
    console.log('\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60));

    const collections = ['users', 'orders', 'refunds', 'login_logs', 'signup_logs'];
    let totalEncrypted = 0;
    let totalErrors = 0;

    collections.forEach(collection => {
        const stat = stats[collection];
        totalEncrypted += stat.encrypted;
        totalErrors += stat.errors;

        console.log(`\n${collection.toUpperCase()}:`);
        console.log(`  Total documents: ${stat.total}`);
        console.log(`  Encrypted: ${stat.encrypted}`);
        console.log(`  Skipped (already encrypted): ${stat.skipped}`);
        console.log(`  Errors: ${stat.errors}`);
    });

    console.log('\n' + '='.repeat(60));
    console.log(`Total documents encrypted: ${totalEncrypted}`);
    console.log(`Total errors: ${totalErrors}`);
    console.log('='.repeat(60));

    if (totalErrors > 0) {
        console.log('\n⚠️  Some documents failed to encrypt. Check the logs above.');
    } else if (totalEncrypted > 0) {
        console.log('\n✅ Migration completed successfully!');
    } else {
        console.log('\n✅ All documents were already encrypted. No changes made.');
    }
}

/**
 * Main migration function
 */
async function main() {
    console.log('🔐 Starting data encryption migration...');
    console.log('⚠️  Make sure you have backed up your database before proceeding!');

    try {
        // Run migrations sequentially
        await migrateUsers();
        await migrateOrders();
        await migrateRefunds();
        await migrateLoginLogs();
        await migrateSignupLogs();

        // Print statistics
        printStats();

    } catch (error) {
        console.error('\n❌ Migration failed:', error);
        process.exit(1);
    } finally {
        // Close Firebase connection
        await admin.app().delete();
        console.log('\n👋 Migration script completed.');
        process.exit(0);
    }
}

// Run migration
if (require.main === module) {
    main();
}

module.exports = { main };
