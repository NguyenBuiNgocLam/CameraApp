import Papa from 'papaparse';
import { createWordId } from './slugify';
import { toNumber } from './formatters';

const COLUMN_ALIASES = {
  no: ['No', 'Number', 'Index', 'STT', 'Stt', 'Số thứ tự'],
  topic: ['Topic', 'Category', 'Group', 'Chủ đề', 'Chu de'],
  word: ['Vocabulary', 'Word', 'English', 'Term', 'Vocab', 'Từ vựng', 'Tu vung'],
  meaningVi: [
    'Vietnamese meaning',
    'Vietnamese Meaning',
    'Meaning',
    'Vietnamese',
    'Meaning VI',
    'meaningVi',
    'Nghĩa tiếng Việt',
    'Nghia tieng Viet',
    'Nghĩa',
    'Nghia',
  ],
  partOfSpeech: [
    'Part of speech',
    'Part of Speech',
    'POS',
    'Type',
    'Word type',
    'Từ loại',
    'Tu loai',
  ],
  sourceStyle: ['Source style', 'Source Style', 'Style', 'Nguồn kiểu', 'Nguon kieu'],
  sourceUrl: ['Source URL', 'Source Url', 'URL', 'Url', 'Link', 'Source'],
};

export function parseVocabularyCsv(file) {
  return new Promise((resolve, reject) => {
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      transformHeader: (header) => header.trim(),
      complete: (result) => {
        if (result.errors.length > 0) {
          reject(new Error(result.errors[0].message || 'Could not parse CSV file.'));
          return;
        }

        resolve(normalizeRows(result.data));
      },
      error: (error) => reject(error),
    });
  });
}

function normalizeRows(rows) {
  const validRows = [];
  const invalidRows = [];
  const headerMap = createHeaderMap(rows[0] || {});

  rows.forEach((row, index) => {
    const normalized = Object.keys(COLUMN_ALIASES).reduce((current, fieldKey) => {
      const csvKey = headerMap[fieldKey];
      current[fieldKey] = String(csvKey ? row[csvKey] ?? '' : '').trim();
      return current;
    }, {});

    const rowNumber = index + 2;
    const errors = [];
    const no = toNumber(normalized.no);

    if (!no) {
      errors.push('No is required and must be a number.');
    }

    if (!normalized.word) {
      errors.push('Vocabulary is required.');
    }

    if (!normalized.meaningVi) {
      errors.push('Vietnamese meaning is required.');
    }

    const wordId = createWordId(no, normalized.word);

    if (!wordId) {
      errors.push('Could not create wordId from No and Vocabulary.');
    }

    const parsedRow = {
      ...normalized,
      no,
      id: wordId,
      rowNumber,
    };

    if (errors.length > 0) {
      invalidRows.push({
        ...parsedRow,
        errors,
      });
    } else {
      validRows.push(parsedRow);
    }
  });

  return {
    validRows,
    invalidRows,
    totalRows: rows.length,
  };
}

function createHeaderMap(row) {
  const headers = Object.keys(row);
  const normalizedHeaders = headers.map((header) => ({
    original: header,
    normalized: normalizeHeader(header),
  }));

  return Object.entries(COLUMN_ALIASES).reduce((current, [fieldKey, aliases]) => {
    const normalizedAliases = aliases.map(normalizeHeader);
    const match = normalizedHeaders.find((header) => normalizedAliases.includes(header.normalized));
    current[fieldKey] = match?.original || '';
    return current;
  }, {});
}

function normalizeHeader(header) {
  return String(header || '')
    .replace(/^\uFEFF/, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
}
