import { Outlet, useNavigate, useOutletContext } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import { logoutAdmin } from '../services/authService';

export default function AdminLayout() {
  const navigate = useNavigate();
  const { admin } = useOutletContext();

  const handleLogout = async () => {
    await logoutAdmin();
    navigate('/login', { replace: true });
  };

  return (
    <div className="flex min-h-screen bg-slate-50">
      <Sidebar onLogout={handleLogout} />

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-16 items-center justify-between border-b border-slate-200 bg-white px-6">
          <div>
            <p className="text-sm font-medium text-slate-500">System vocabulary admin</p>
          </div>

          <div className="flex items-center gap-4">
            <span className="max-w-64 truncate text-sm font-medium text-slate-700">
              {admin?.email}
            </span>
            <button
              type="button"
              onClick={handleLogout}
              className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white hover:bg-slate-700"
            >
              Logout
            </button>
          </div>
        </header>

        <main className="flex-1 p-6">
          <Outlet context={{ admin }} />
        </main>
      </div>
    </div>
  );
}
