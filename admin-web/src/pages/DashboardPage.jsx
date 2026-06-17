import { useEffect, useState } from 'react';
import { Link, useOutletContext } from 'react-router-dom';
import StatCard from '../components/StatCard';
import { getVocabularySetStats } from '../services/vocabularySetService';
import { formatDate } from '../utils/formatters';

export default function DashboardPage() {
  const { admin } = useOutletContext();
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadStats() {
      try {
        setLoading(true);
        setError('');
        setStats(await getVocabularySetStats());
      } catch (loadError) {
        setError(loadError.message || 'Could not load dashboard.');
      } finally {
        setLoading(false);
      }
    }

    loadStats();
  }, []);

  return (
    <section>
      <div className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-slate-950">Dashboard</h2>
          <p className="mt-1 text-sm text-slate-600">Welcome back, {admin?.email}.</p>
        </div>
        <Link
          to="/sets/new"
          className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
        >
          Create New Set
        </Link>
      </div>

      {loading ? (
        <StateBox>Loading dashboard...</StateBox>
      ) : error ? (
        <StateBox tone="error">{error}</StateBox>
      ) : (
        <>
          <div className="grid gap-4 md:grid-cols-3">
            <StatCard label="Total vocabulary sets" value={stats.totalSets} />
            <StatCard label="Total system words" value={stats.totalWords} />
            <StatCard label="TOEIC 600 words count" value={stats.toeic600Words} />
          </div>

          <div className="mt-6 rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="border-b border-slate-200 px-5 py-4">
              <h3 className="text-lg font-bold text-slate-950">Latest updated sets</h3>
            </div>

            {stats.latestSets.length === 0 ? (
              <div className="px-5 py-8 text-center text-sm text-slate-500">
                No vocabulary sets yet.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-slate-200 text-sm">
                  <thead className="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                    <tr>
                      <th className="px-5 py-3">Name</th>
                      <th className="px-5 py-3">Total Words</th>
                      <th className="px-5 py-3">Updated At</th>
                      <th className="px-5 py-3">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200">
                    {stats.latestSets.map((item) => (
                      <tr key={item.id}>
                        <td className="px-5 py-3">
                          <p className="font-semibold text-slate-900">{item.name}</p>
                          <p className="text-xs text-slate-500">{item.id}</p>
                        </td>
                        <td className="px-5 py-3 text-slate-700">{item.totalWords || 0}</td>
                        <td className="px-5 py-3 text-slate-700">{formatDate(item.updatedAt)}</td>
                        <td className="px-5 py-3">
                          <Link className="font-semibold text-blue-700 hover:text-blue-900" to={`/sets/${item.id}/words`}>
                            View Words
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </section>
  );
}

function StateBox({ children, tone = 'default' }) {
  const classes =
    tone === 'error'
      ? 'border-red-200 bg-red-50 text-red-700'
      : 'border-slate-200 bg-white text-slate-600';

  return (
    <div className={`rounded-lg border p-8 text-center text-sm font-medium ${classes}`}>
      {children}
    </div>
  );
}
