const admin = require('firebase-admin');
const sa = require('./firebase-service-account.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
module.exports = admin;
