import { useEffect, useMemo, useState } from 'react';
import { importVocabularyRows } from '../services/csvImportService';
import { getVocabularySets } from '../services/vocabularySetService';
import { parseVocabularyCsv } from '../utils/csvParser';

export default function ImportCsvPage() {
  const [sets, setSets] = useState([]);
  const [setId, setSetId] = useState('');
  const [validRows, setValidRows] = useState([]);
  const [invalidRows, setInvalidRows] = useState([]);
  const [totalRows, setTotalRows] = useState(0);
  const [loadingSets, setLoadingSets] = useState(true);
  const [parsing, setParsing] = useState(false);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    async function loadSets() {
      try {
        setLoadingSets(true);
        const data = await getVocabularySets();
        setSets(data);
        setSetId(data[0]?.id || '');
      } catch (loadError) {
        setError(loadError.message || 'Could not load vocabulary sets.');
      } finally {
        setLoadingSets(false);
      }
    }

    loadSets();
  }, []);

  const previewRows = useMemo(() => validRows.slice(0, 20), [validRows]);

  const handleFileChange = async (event) => {
    const file = event.target.files?.[0];
    setError('');
    setSuccess('');
    setValidRows([]);
    setInvalidRows([]);
    setTotalRows(0);

    if (!file) {
      return;
    }

    try {
      setParsing(true);
      const result = await parseVocabularyCsv(file);
      setValidRows(result.validRows);
      setInvalidRows(result.invalidRows);
      setTotalRows(result.totalRows);
    } catch (parseError) {
      setError(parseError.message || 'Could not parse CSV file.');
    } finally {
      setParsing(false);
    }
  };

  const handleImport = async () => {
    try {
      setImporting(true);
      setError('');
      setSuccess('');
      const result = await importVocabularyRows(setId, validRows);
      setSuccess(`Imported ${result.imported} rows. Total words is now ${result.totalWords}.`);
    } catch (importError) {
      setError(importError.message || 'Could not import CSV.');
    } finally {
      setImporting(false);
    }
  };

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-slate-950">Import CSV</h2>
        <p className="mt-1 text-sm text-slate-600">
          Import words into an existing system vocabulary set.
        </p>
      </div>

      {error ? <Alert tone="error">{error}</Alert> : null}
      {success ? <Alert tone="success">{success}</Alert> : null}

      <div className="grid gap-5 lg:grid-cols-[380px_1fr]">
        <div className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <div className="space-y-5">
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-slate-700">Vocabulary Set</span>
              <select
                value={setId}
                onChange={(event) => setSetId(event.target.value)}
                disabled={loadingSets}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
              >
                {sets.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.name} ({item.id})
                  </option>
                ))}
              </select>
            </label>

            <label className="block">
              <span className="mb-1 block text-sm font-medium text-slate-700">CSV File</span>
              <input
                type="file"
                accept=".csv,text/csv"
                onChange={handleFileChange}
                className="block w-full text-sm text-slate-700 file:mr-4 file:rounded-md file:border-0 file:bg-slate-900 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white hover:file:bg-slate-700"
              />
            </label>

            <div className="grid grid-cols-3 gap-3">
              <SummaryCard label="Rows" value={totalRows} />
              <SummaryCard label="Valid" value={validRows.length} />
              <SummaryCard label="Errors" value={invalidRows.length} />
            </div>

            <button
              type="button"
              onClick={handleImport}
              disabled={importing || parsing || !setId || validRows.length === 0}
              className="w-full rounded-md bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-blue-300"
            >
              {importing ? 'Importing...' : parsing ? 'Parsing...' : 'Import Valid Rows'}
            </button>

            <div className="rounded-md bg-slate-50 p-4 text-xs leading-6 text-slate-600">
              <p className="font-semibold text-slate-800">Required CSV columns</p>
              <p>No, Topic, Vocabulary or Word, Part of speech, Vietnamese meaning or Meaning, Source style, Source URL</p>
            </div>
          </div>
        </div>

        <div className="space-y-5">
          <div className="rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="border-b border-slate-200 px-5 py-4">
              <h3 className="text-lg font-bold text-slate-950">Preview</h3>
            </div>

            {previewRows.length === 0 ? (
              <StateBox>No valid rows to preview.</StateBox>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-slate-200 text-sm">
                  <thead className="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                    <tr>
                      <th className="px-5 py-3">No</th>
                      <th className="px-5 py-3">Topic</th>
                      <th className="px-5 py-3">Vocabulary</th>
                      <th className="px-5 py-3">Meaning VI</th>
                      <th className="px-5 py-3">Part of Speech</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200">
                    {previewRows.map((row) => (
                      <tr key={`${row.rowNumber}_${row.id}`}>
                        <td className="px-5 py-3 text-slate-700">{row.no}</td>
                        <td className="px-5 py-3 text-slate-700">{row.topic || '-'}</td>
                        <td className="px-5 py-3 font-semibold text-slate-900">{row.word}</td>
                        <td className="px-5 py-3 text-slate-700">{row.meaningVi}</td>
                        <td className="px-5 py-3 text-slate-700">{row.partOfSpeech || '-'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {invalidRows.length > 0 ? (
            <div className="rounded-lg border border-red-200 bg-white shadow-sm">
              <div className="border-b border-red-100 px-5 py-4">
                <h3 className="text-lg font-bold text-red-700">Invalid Rows</h3>
              </div>
              <div className="max-h-72 overflow-auto">
                <table className="min-w-full divide-y divide-red-100 text-sm">
                  <thead className="bg-red-50 text-left text-xs font-semibold uppercase tracking-wide text-red-600">
                    <tr>
                      <th className="px-5 py-3">Row</th>
                      <th className="px-5 py-3">Vocabulary</th>
                      <th className="px-5 py-3">Errors</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-red-100">
                    {invalidRows.map((row) => (
                      <tr key={`invalid_${row.rowNumber}`}>
                        <td className="px-5 py-3 text-slate-700">{row.rowNumber}</td>
                        <td className="px-5 py-3 text-slate-700">{row.word || '-'}</td>
                        <td className="px-5 py-3 text-red-700">{row.errors.join(' ')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </section>
  );
}

function Alert({ children, tone }) {
  const classes =
    tone === 'success'
      ? 'border-green-200 bg-green-50 text-green-700'
      : 'border-red-200 bg-red-50 text-red-700';
  return <div className={`mb-4 rounded-md border px-4 py-3 text-sm ${classes}`}>{children}</div>;
}

function SummaryCard({ label, value }) {
  return (
    <div className="rounded-md border border-slate-200 bg-slate-50 p-3 text-center">
      <p className="text-xs font-medium text-slate-500">{label}</p>
      <p className="mt-1 text-xl font-bold text-slate-950">{value}</p>
    </div>
  );
}

function StateBox({ children }) {
  return <div className="p-8 text-center text-sm font-medium text-slate-500">{children}</div>;
}
