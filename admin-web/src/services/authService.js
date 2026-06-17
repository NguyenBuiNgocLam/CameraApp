import { signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';

export const ADMIN_DENIED_MESSAGE = 'You are not allowed to access admin dashboard.';

export async function getAdminProfile(user) {
  if (!user) {
    return null;
  }

  const adminRef = doc(db, 'admins', user.uid);
  const adminSnap = await getDoc(adminRef);

  if (!adminSnap.exists()) {
    return null;
  }

  const data = adminSnap.data();

  if (data.role && data.role !== 'admin') {
    return null;
  }

  return {
    uid: user.uid,
    email: user.email,
    ...data,
  };
}

export async function loginAdmin(email, password) {
  const credential = await signInWithEmailAndPassword(auth, email, password);
  const adminProfile = await getAdminProfile(credential.user);

  if (!adminProfile) {
    await signOut(auth);
    throw new Error(ADMIN_DENIED_MESSAGE);
  }

  return adminProfile;
}

export function logoutAdmin() {
  return signOut(auth);
}
