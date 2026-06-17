import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import { isFirebaseConfigured, missingFirebaseConfig } from './firebase';
import AdminLayout from './layouts/AdminLayout';
import ComingSoonPage from './pages/ComingSoonPage';
import DashboardPage from './pages/DashboardPage';
import ImportCsvPage from './pages/ImportCsvPage';
import LoginPage from './pages/LoginPage';
import VocabularySetFormPage from './pages/VocabularySetFormPage';
import VocabularySetsPage from './pages/VocabularySetsPage';
import WordsPage from './pages/WordsPage';

export default function App() {
  if (!isFirebaseConfigured) {
    return <FirebaseConfigError missingKeys={missingFirebaseConfig} />;
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<ProtectedRoute />}>
          <Route element={<AdminLayout />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/sets" element={<VocabularySetsPage />} />
            <Route path="/sets/new" element={<VocabularySetFormPage />} />
            <Route path="/sets/:setId/edit" element={<VocabularySetFormPage />} />
            <Route path="/sets/:setId/words" element={<WordsPage />} />
            <Route path="/import-csv" element={<ImportCsvPage />} />
          </Route>
        </Route>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

function FirebaseConfigError({ missingKeys }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-100 px-4 py-10">
      <div className="w-full max-w-2xl rounded-lg border border-amber-200 bg-white p-8 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-wide text-amber-700">
          Firebase config missing
        </p>
        <h1 className="mt-2 text-2xl font-bold text-slate-950">Admin web is not configured yet</h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          Create <span className="font-mono font-semibold">admin-web/.env</span> from{' '}
          <span className="font-mono font-semibold">admin-web/.env.example</span>, fill Firebase
          Web SDK values, then restart <span className="font-mono font-semibold">npm run dev</span>.
        </p>

        <div className="mt-5 rounded-md bg-slate-950 p-4 text-sm text-slate-100">
          {missingKeys.map((key) => (
            <div key={key}>{key}=</div>
          ))}
        </div>
      </div>
    </div>
  );
}
