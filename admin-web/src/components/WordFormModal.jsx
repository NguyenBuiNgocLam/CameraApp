import { useEffect, useState } from 'react';

const emptyForm = {
  no: '',
  topic: '',
  word: '',
  meaningVi: '',
  partOfSpeech: '',
  sourceStyle: '',
  sourceUrl: '',
};

export default function WordFormModal({ isOpen, word, onClose, onSubmit }) {
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setForm(word ? { ...emptyForm, ...word } : emptyForm);
      setError('');
      setSaving(false);
    }
  }, [isOpen, word]);

  if (!isOpen) {
    return null;
  }

  const handleChange = (event) => {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError('');

    try {
      await onSubmit(form);
      onClose();
    } catch (submitError) {
      setError(submitError.message || 'Could not save word.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4">
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-lg bg-white shadow-xl">
        <div className="border-b border-slate-200 px-6 py-4">
          <h2 className="text-lg font-bold text-slate-950">{word ? 'Edit Word' : 'Add Word'}</h2>
        </div>

        <form className="space-y-5 px-6 py-5" onSubmit={handleSubmit}>
          {error ? (
            <div className="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          ) : null}

          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="No" name="no" type="number" value={form.no} onChange={handleChange} required />
            <Field label="Topic" name="topic" value={form.topic} onChange={handleChange} required />
            <Field label="Word" name="word" value={form.word} onChange={handleChange} required />
            <Field
              label="Part of Speech"
              name="partOfSpeech"
              value={form.partOfSpeech}
              onChange={handleChange}
            />
            <Field
              label="Vietnamese Meaning"
              name="meaningVi"
              value={form.meaningVi}
              onChange={handleChange}
              required
            />
            <Field
              label="Source Style"
              name="sourceStyle"
              value={form.sourceStyle}
              onChange={handleChange}
            />
          </div>

          <Field label="Source URL" name="sourceUrl" value={form.sourceUrl} onChange={handleChange} />

          <div className="flex justify-end gap-3 border-t border-slate-200 pt-5">
            <button
              type="button"
              onClick={onClose}
              className="rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:bg-blue-300"
            >
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function Field({ label, name, value, onChange, type = 'text', required = false }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-slate-700">{label}</span>
      <input
        name={name}
        type={type}
        value={value}
        onChange={onChange}
        required={required}
        className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
      />
    </label>
  );
}
