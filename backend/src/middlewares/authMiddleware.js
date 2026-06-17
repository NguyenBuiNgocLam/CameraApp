import { getFirebaseAdmin } from '../config/firebaseAdmin.js';

export async function authMiddleware(req, res, next) {
  const authorization = req.headers.authorization || '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({
      error: 'Unauthorized: Missing token',
    });
  }

  try {
    const admin = getFirebaseAdmin();
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email ?? '',
      name: decodedToken.name ?? '',
      picture: decodedToken.picture ?? '',
    };
    return next();
  } catch (error) {
    console.error('Firebase token verification failed:', error?.message);
    return res.status(401).json({
      error: 'Unauthorized: Invalid token',
    });
  }
}
