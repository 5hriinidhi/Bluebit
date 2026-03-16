const admin = require('firebase-admin');

let serviceAccount;

// 1. Try environment variable (Production/Railway)
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (err) {
    console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT env var:', err.message);
  }
} 

// 2. Fallback to local file (Development)
if (!serviceAccount) {
  try {
    serviceAccount = require('./firebase-service-account.json');
  } catch (err) {
    console.warn('Firebase service account file not found. Push notifications will fail.');
  }
}

if (!admin.apps.length && serviceAccount) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

module.exports = admin;
