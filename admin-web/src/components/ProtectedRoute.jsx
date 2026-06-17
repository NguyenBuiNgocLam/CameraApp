import { useEffect, useState } from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from '../firebase';
import { ADMIN_DENIED_MESSAGE, getAdminProfile, logoutAdmin } from '../services/authService';

export default function ProtectedRoute() {
  const location = useLocation();
  const [status, setStatus] = useState('checking');
  const [admin, setAdmin] = useState(null);

  useEffect(() => {
    let isMounted = true;

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!isMounted) {
        return;
      }

      if (!user) {
        setAdmin(null);
        setStatus('unauthenticated');
        return;
      }

      try {
        const adminProfile = await getAdminProfile(user);

        if (!adminProfile) {
          await logoutAdmin();
          if (isMounted) {
            setAdmin(null);
            setStatus('not-admin');
          }
          return;
        }

        if (isMounted) {
          setAdmin(adminProfile);
          setStatus('authorized');
        }
      } catch (error) {
        console.error('Admin check failed:', error);
        await logoutAdmin();
        if (isMounted) {
          setAdmin(null);
          setStatus('not-admin');
        }
      }
    });

    return () => {
      isMounted = false;
      unsubscribe();
    };
  }, []);

  if (status === 'checking') {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50 text-slate-700">
        Checking admin access...
      </div>
    );
  }

  if (status === 'unauthenticated') {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (status === 'not-admin') {
    return <Navigate to="/login" replace state={{ error: ADMIN_DENIED_MESSAGE }} />;
  }

  return <Outlet context={{ admin }} />;
}
