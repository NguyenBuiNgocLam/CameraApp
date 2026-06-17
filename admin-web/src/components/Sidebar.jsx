import { NavLink } from 'react-router-dom';

const navigation = [
  { label: 'Dashboard', to: '/dashboard' },
  { label: 'Vocabulary Sets', to: '/sets' },
  { label: 'Add Vocabulary Set', to: '/sets/new' },
  { label: 'Import CSV', to: '/import-csv' },
];

export default function Sidebar({ onLogout }) {
  return (
    <aside className="flex h-full w-64 flex-col border-r border-slate-200 bg-white">
      <div className="border-b border-slate-200 px-6 py-5">
        <p className="text-sm font-semibold uppercase tracking-wide text-blue-600">Admin</p>
        <h1 className="mt-1 text-xl font-bold text-slate-900">Vocabulary</h1>
      </div>

      <nav className="flex-1 space-y-1 px-3 py-4">
        {navigation.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              [
                'block rounded-md px-3 py-2 text-sm font-medium transition',
                isActive ? 'bg-blue-50 text-blue-700' : 'text-slate-700 hover:bg-slate-100',
              ].join(' ')
            }
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-slate-200 p-3">
        <button
          type="button"
          onClick={onLogout}
          className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
        >
          Logout
        </button>
      </div>
    </aside>
  );
}
