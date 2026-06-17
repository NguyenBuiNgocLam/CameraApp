import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { deleteVocabularySet, getVocabularySets } from '../services/vocabularySetService';
import { formatDate } from '../utils/formatters';

export default function VocabularySetsPage() {
  const [sets, setSets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [deletingId, setDeletingId] = useState('');

  const loadSets = async () => {
    try {
      setLoading(true);
      setError('');
      setSets(await getVocabularySets());
    } catch (loadError) {
      setError(loadError.message || 'Could not load vocabulary sets.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSets();
  }, []);

  const handleDelete = async (setItem) => {
    const confirmed = window.confirm(
      `Delete "${setItem.name}" and all words inside this set? This cannot be undone.`,
    );

    if (!confirmed) {
      return;
    }

    try {
      setDeletingId(setItem.id);
      await deleteVocabularySet(setItem.id);
      await loadSets();
    } catch (deleteError) {
      setError(deleteError.message || 'Could not delete vocabulary set.');
    } finally {
      setDeletingId('');
    }
  };

  return (
    <section>
      <div className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-slate-950">Vocabulary Sets</h2>
          <p className="mt-1 text-sm text-slate-600">Manage system vocabulary collections.</p>
        </div>
        <Link
          to="/sets/new"
          className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
        >
          Create New Set
        </Link>
      </div>

      {error ? (
        <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      ) : null}

      <div className="rounded-lg border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <StateBox>Loading vocabulary sets...</StateBox>
        ) : sets.length === 0 ? (
          <StateBox>No vocabulary sets yet.</StateBox>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-5 py-3">Name</th>
                  <th className="px-5 py-3">Description</th>
                  <th className="px-5 py-3">Total Words</th>
                  <th className="px-5 py-3">Source Style</th>
                  <th className="px-5 py-3">Updated At</th>
                  <th className="px-5 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {sets.map((setItem) => (
                  <tr key={setItem.id} className="align-top">
                    <td className="px-5 py-4">
                      <p className="font-semibold text-slate-900">{setItem.name}</p>
                      <p className="text-xs text-slate-500">{setItem.id}</p>
                    </td>
                    <td className="max-w-sm px-5 py-4 text-slate-700">{setItem.description || '-'}</td>
                    <td className="px-5 py-4 text-slate-700">{setItem.totalWords || 0}</td>
                    <td className="px-5 py-4 text-slate-700">{setItem.sourceStyle || '-'}</td>
                    <td className="px-5 py-4 text-slate-700">{formatDate(setItem.updatedAt)}</td>
                    <td className="px-5 py-4">
                      <div className="flex flex-wrap gap-3">
                        <Link className="font-semibold text-blue-700 hover:text-blue-900" to={`/sets/${setItem.id}/words`}>
                          View Words
                        </Link>
                        <Link className="font-semibold text-slate-700 hover:text-slate-950" to={`/sets/${setItem.id}/edit`}>
                          Edit
                        </Link>
                        <button
                          type="button"
                          onClick={() => handleDelete(setItem)}
                          disabled={deletingId === setItem.id}
                          className="font-semibold text-red-600 hover:text-red-800 disabled:text-red-300"
                        >
                          {deletingId === setItem.id ? 'Deleting...' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}

function StateBox({ children }) {
  return <div className="p-8 text-center text-sm font-medium text-slate-500">{children}</div>;
}
