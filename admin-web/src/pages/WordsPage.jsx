import { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import WordFormModal from '../components/WordFormModal';
import { getVocabularySet } from '../services/vocabularySetService';
import { addWord, deleteWord, getWords, updateWord } from '../services/wordService';

export default function WordsPage() {
  const { setId } = useParams();
  const [setItem, setSetItem] = useState(null);
  const [words, setWords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [topic, setTopic] = useState('all');
  const [modalOpen, setModalOpen] = useState(false);
  const [editingWord, setEditingWord] = useState(null);
  const [deletingId, setDeletingId] = useState('');

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const [setData, wordData] = await Promise.all([getVocabularySet(setId), getWords(setId)]);
      setSetItem(setData);
      setWords(wordData);
    } catch (loadError) {
      setError(loadError.message || 'Could not load words.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [setId]);

  const topics = useMemo(() => {
    const uniqueTopics = new Set(words.map((item) => item.topic).filter(Boolean));
    return Array.from(uniqueTopics).sort((a, b) => a.localeCompare(b));
  }, [words]);

  const filteredWords = useMemo(() => {
    const keyword = search.trim().toLowerCase();

    return words.filter((item) => {
      const matchesTopic = topic === 'all' || item.topic === topic;
      const searchable = `${item.word || ''} ${item.meaningVi || ''} ${item.topic || ''}`.toLowerCase();
      const matchesSearch = !keyword || searchable.includes(keyword);
      return matchesTopic && matchesSearch;
    });
  }, [words, search, topic]);

  const openAddModal = () => {
    setEditingWord(null);
    setModalOpen(true);
  };

  const openEditModal = (word) => {
    setEditingWord(word);
    setModalOpen(true);
  };

  const handleSubmitWord = async (values) => {
    if (editingWord) {
      await updateWord(setId, editingWord.id, values);
    } else {
      await addWord(setId, values);
    }

    await loadData();
  };

  const handleDeleteWord = async (word) => {
    const confirmed = window.confirm(`Delete "${word.word}" from this vocabulary set?`);

    if (!confirmed) {
      return;
    }

    try {
      setDeletingId(word.id);
      setError('');
      await deleteWord(setId, word.id);
      await loadData();
    } catch (deleteError) {
      setError(deleteError.message || 'Could not delete word.');
    } finally {
      setDeletingId('');
    }
  };

  return (
    <section>
      <div className="mb-6">
        <Link className="text-sm font-semibold text-blue-700 hover:text-blue-900" to="/sets">
          Back to sets
        </Link>
        <div className="mt-2 flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-2xl font-bold text-slate-950">
              {setItem?.name || setId}
            </h2>
            <p className="mt-1 text-sm text-slate-600">
              Manage words in <span className="font-semibold">{setId}</span>.
            </p>
          </div>
          <button
            type="button"
            onClick={openAddModal}
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            Add Word
          </button>
        </div>
      </div>

      {error ? (
        <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      ) : null}

      <div className="mb-4 grid gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm md:grid-cols-[1fr_260px]">
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-slate-700">Search</span>
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search word, Vietnamese meaning, or topic"
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-slate-700">Topic</span>
          <select
            value={topic}
            onChange={(event) => setTopic(event.target.value)}
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
          >
            <option value="all">All topics</option>
            {topics.map((topicName) => (
              <option key={topicName} value={topicName}>
                {topicName}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="rounded-lg border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <StateBox>Loading words...</StateBox>
        ) : words.length === 0 ? (
          <StateBox>No words in this set yet.</StateBox>
        ) : filteredWords.length === 0 ? (
          <StateBox>No words match your search or filter.</StateBox>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-5 py-3">No</th>
                  <th className="px-5 py-3">Topic</th>
                  <th className="px-5 py-3">Word</th>
                  <th className="px-5 py-3">Meaning VI</th>
                  <th className="px-5 py-3">Part of Speech</th>
                  <th className="px-5 py-3">Source Style</th>
                  <th className="px-5 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {filteredWords.map((word) => (
                  <tr key={word.id} className="align-top">
                    <td className="px-5 py-4 text-slate-700">{word.no}</td>
                    <td className="px-5 py-4 text-slate-700">{word.topic || '-'}</td>
                    <td className="px-5 py-4">
                      <p className="font-semibold text-slate-900">{word.word}</p>
                      <p className="text-xs text-slate-500">{word.id}</p>
                    </td>
                    <td className="max-w-sm px-5 py-4 text-slate-700">{word.meaningVi || '-'}</td>
                    <td className="px-5 py-4 text-slate-700">{word.partOfSpeech || '-'}</td>
                    <td className="px-5 py-4 text-slate-700">{word.sourceStyle || '-'}</td>
                    <td className="px-5 py-4">
                      <div className="flex gap-3">
                        <button
                          type="button"
                          onClick={() => openEditModal(word)}
                          className="font-semibold text-slate-700 hover:text-slate-950"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDeleteWord(word)}
                          disabled={deletingId === word.id}
                          className="font-semibold text-red-600 hover:text-red-800 disabled:text-red-300"
                        >
                          {deletingId === word.id ? 'Deleting...' : 'Delete'}
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

      <WordFormModal
        isOpen={modalOpen}
        word={editingWord}
        onClose={() => setModalOpen(false)}
        onSubmit={handleSubmitWord}
      />
    </section>
  );
}

function StateBox({ children }) {
  return <div className="p-8 text-center text-sm font-medium text-slate-500">{children}</div>;
}
