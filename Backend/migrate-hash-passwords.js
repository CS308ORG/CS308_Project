/**
 * Password Migration Script - Hash Existing Plain Text Passwords with bcrypt
 *
 * This script hashes all existing plain text passwords in the database using bcrypt.
 * It skips passwords that are already hashed (starting with $2b$).
 *
 * IMPORTANT: Run this script ONCE after deploying password hashing changes
 * Make sure to backup your database before running this script!
 */

require('dotenv').config();
const admin = require('firebase-admin');
const bcrypt = require('bcrypt');

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

// bcrypt salt rounds (same as in index.js and auth-routes.js)
const saltRounds = 10;

// Migration statistics
const stats = {
    total: 0,
    hashed: 0,
    skipped: 0,
    noPassword: 0,
    errors: 0
};

/**
 * Check if password is already hashed with bcrypt
 */
function isAlreadyHashed(password) {
    return password && password.startsWith('$2b$');
}

/**
 * Migrate user passwords
 */
async function migratePasswords() {
    console.log('\n🔐 Migrating user passwords to bcrypt...');
    const snapshot = await db.collection('users').get();
    stats.total = snapshot.size;

    for (const doc of snapshot.docs) {
        try {
            const data = doc.data();
            const password = data.password;

            // Skip if no password
            if (!password) {
                stats.noPassword++;
                console.log(`  ⚠ User ${doc.id} (${data.name || 'No name'}) has no password`);
                continue;
            }

            // Skip if already hashed
            if (isAlreadyHashed(password)) {
                stats.skipped++;
                continue;
            }

            // Hash the plain text password
            const hashedPassword = await bcrypt.hash(password, saltRounds);

            await doc.ref.update({ password: hashedPassword });
            stats.hashed++;
            console.log(`  ✓ Hashed password for user ${doc.id} (${data.name || 'No name'})`);

        } catch (error) {
            stats.errors++;
            console.error(`  ✗ Error hashing password for user ${doc.id}:`, error.message);
        }
    }
}

/**
 * Print migration statistics
 */
function printStats() {
    console.log('\n' + '='.repeat(60));
    console.log('📊 PASSWORD MIGRATION SUMMARY');
    console.log('='.repeat(60));

    console.log(`\nTotal users: ${stats.total}`);
    console.log(`Passwords hashed: ${stats.hashed}`);
    console.log(`Skipped (already hashed): ${stats.skipped}`);
    console.log(`Users without password: ${stats.noPassword}`);
    console.log(`Errors: ${stats.errors}`);

    console.log('\n' + '='.repeat(60));

    if (stats.errors > 0) {
        console.log('\n⚠️  Some passwords failed to hash. Check the logs above.');
    } else if (stats.hashed > 0) {
        console.log('\n✅ Password migration completed successfully!');
    } else {
        console.log('\n✅ All passwords were already hashed. No changes made.');
    }
}

/**
 * Main migration function
 */
async function main() {
    console.log('🔐 Starting password hashing migration...');
    console.log('⚠️  Make sure you have backed up your database before proceeding!');
    console.log(`📝 Using ${saltRounds} salt rounds for bcrypt`);

    try {
        await migratePasswords();
        printStats();

    } catch (error) {
        console.error('\n❌ Migration failed:', error);
        process.exit(1);
    } finally {
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
