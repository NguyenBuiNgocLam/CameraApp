import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  createVocabularySet,
  getVocabularySet,
  updateVocabularySet,
} from '../services/vocabularySetService';
import { slugify } from '../utils/slugify';

const emptyForm = {
  id: '',
  name: '',
  description: '',
  sourceStyle: '',
  sourceUrl: '',
};

export default function VocabularySetFormPage() {
  const { setId } = useParams();
  const isEditing = Boolean(setId);
  const navigate = useNavigate();
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(isEditing);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const title = isEditing ? 'Edit Vocabulary Set' : 'Create Vocabulary Set';
  const suggestedId = useMemo(() => slugify(form.name), [form.name]);

  useEffect(() => {
    async function loadSet() {
      if (!isEditing) {
        return;
      }

      try {
        setLoading(true);
        const data = await getVocabularySet(setId);
        if (!data) {
          setError('Vocabulary set not found.');
          return;
        }
        setForm({
          id: data.id || setId,
          name: data.name || '',
          description: data.description || '',
          sourceStyle: data.sourceStyle || '',
          sourceUrl: data.sourceUrl || '',
        });
      } catch (loadError) {
        setError(loadError.message || 'Could not load vocabulary set.');
      } finally {
        setLoading(false);
      }
    }

    loadSet();
  }, [isEditing, setId]);

  const handleChange = (event) => {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: name === 'id' ? slugify(value) : value }));
  };

  const applySuggestedId = () => {
    setForm((current) => ({ ...current, id: suggestedId }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError('');

    try {
      if (isEditing) {
        await updateVocabularySet(setId, form);
      } else {
        await createVocabularySet(form);
      }

      navigate('/sets');
    } catch (submitError) {
      setError(submitError.message || 'Could not save vocabulary set.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="rounded-lg border border-slate-200 bg-white p-8 text-center text-sm text-slate-600">Loading set...</div>;
  }

  return (
    <section className="max-w-3xl">
      <div className="mb-6">
        <Link className="text-sm font-semibold text-blue-700 hover:text-blue-900" to="/sets">
          Back to sets
        </Link>
        <h2 className="mt-2 text-2xl font-bold text-slate-950">{title}</h2>
        <p className="mt-1 text-sm text-slate-600">Use a stable slug id like toeic_600, b1_vocabulary, or ielts_essential.</p>
      </div>

      <form className="rounded-lg border border-slate-200 bg-white p-6 shadow-sm" onSubmit={handleSubmit}>
        {error ? (
          <div className="mb-5 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        ) : null}

        <div className="space-y-5">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-slate-700">Set ID</span>
            <div className="flex gap-2">
              <input
                name="id"
                value={form.id}
                onChange={handleChange}
                disabled={isEditing}
                required
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 disabled:bg-slate-100"
                placeholder="toeic_600"
              />
              {!isEditing ? (
                <button
                  type="button"
                  onClick={applySuggestedId}
                  disabled={!suggestedId}
                  className="shrink-0 rounded-md border border-slate-300 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100 disabled:text-slate-300"
                >
                  Use Slug
                </button>
              ) : null}
            </div>
          </label>

          <Field label="Name" name="name" value={form.name} onChange={handleChange} required />
          <TextArea label="Description" name="description" value={form.description} onChange={handleChange} />
          <Field label="Source Style" name="sourceStyle" value={form.sourceStyle} onChange={handleChange} />
          <Field label="Source URL" name="sourceUrl" value={form.sourceUrl} onChange={handleChange} />
        </div>

        <div className="mt-6 flex justify-end gap-3 border-t border-slate-200 pt-5">
          <Link
            to="/sets"
            className="rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
          >
            Cancel
          </Link>
          <button
            type="submit"
            disabled={saving}
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:bg-blue-300"
          >
            {saving ? 'Saving...' : 'Save Set'}
          </button>
        </div>
      </form>
    </section>
  );
}

function Field({ label, name, value, onChange, required = false }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-slate-700">{label}</span>
      <input
        name={name}
        value={value}
        onChange={onChange}
        required={required}
        className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
      />
    </label>
  );
}

function TextArea({ label, name, value, onChange }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-slate-700">{label}</span>
      <textarea
        name={name}
        value={value}
        onChange={onChange}
        rows={4}
        className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
      />
    </label>
  );
}
