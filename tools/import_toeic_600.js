const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const SET_ID = 'toeic_600';
const SET_NAME = 'TOEIC Essential 600';
const SET_DESCRIPTION = '600 TOEIC vocabulary words by topic';
const MAX_BATCH_SIZE = 500;

function resolveCsvPath() {
  const candidates = [
    process.argv[2],
    process.env.CSV_PATH,
    path.resolve(process.cwd(), 'toeic_vocabulary_600_lingoland_style.csv'),
    path.resolve(__dirname, 'toeic_vocabulary_600_lingoland_style.csv'),
    process.env.USERPROFILE
      ? path.resolve(
          process.env.USERPROFILE,
          'Downloads',
          'toeic_vocabulary_600_lingoland_style.csv',
        )
      : null,
  ].filter(Boolean);

  const csvPath = candidates.find((candidate) => fs.existsSync(candidate));
  if (!csvPath) {
    throw new Error(
      'CSV file not found. Pass the path as an argument or set CSV_PATH.',
    );
  }
  return csvPath;
}

function initFirebaseAdmin() {
  if (admin.apps.length > 0) return;

  const serviceAccountPath =
    process.env.SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(process.cwd(), 'backend', 'serviceAccountKey.json') ||
    path.resolve(process.cwd(), 'serviceAccountKey.json');

  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

function createWordId(no, word) {
  const safeNo = String(no).padStart(3, '0');
  const safeWord = String(word)
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

  return `${safeNo}_${safeWord || 'word'}`;
}

function parseCsvLine(line) {
  const values = [];
  let current = '';
  let inQuotes = false;

  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    const nextChar = line[index + 1];

    if (char === '"' && inQuotes && nextChar === '"') {
      current += '"';
      index += 1;
      continue;
    }

    if (char === '"') {
      inQuotes = !inQuotes;
      continue;
    }

    if (char === ',' && !inQuotes) {
      values.push(current);
      current = '';
      continue;
    }

    current += char;
  }

  values.push(current);
  return values;
}

function splitCsvRows(content) {
  const rows = [];
  let current = '';
  let inQuotes = false;

  for (let index = 0; index < content.length; index += 1) {
    const char = content[index];
    const nextChar = content[index + 1];

    if (char === '"' && inQuotes && nextChar === '"') {
      current += char + nextChar;
      index += 1;
      continue;
    }

    if (char === '"') {
      inQuotes = !inQuotes;
      current += char;
      continue;
    }

    if ((char === '\n' || char === '\r') && !inQuotes) {
      if (current.trim()) rows.push(current);
      current = '';
      if (char === '\r' && nextChar === '\n') index += 1;
      continue;
    }

    current += char;
  }

  if (current.trim()) rows.push(current);
  return rows;
}

function readCsv(csvPath) {
  const content = fs.readFileSync(csvPath, 'utf8').replace(/^\uFEFF/, '');
  const rows = splitCsvRows(content);
  if (rows.length === 0) return [];

  const headers = parseCsvLine(rows[0]).map((header) => header.trim());
  return rows.slice(1).map((line) => {
    const values = parseCsvLine(line);
    return headers.reduce((row, header, index) => {
      row[header] = (values[index] || '').trim();
      return row;
    }, {});
  });
}

function normalizeRow(row) {
  const no = Number.parseInt(row.No, 10);
  const word = String(row.Vocabulary || '').trim();

  if (!Number.isFinite(no) || !word) {
    return null;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const sourceStyle = String(row['Source style'] || '').trim();
  const sourceUrl = String(row['Source URL'] || '').trim();

  return {
    id: createWordId(no, word),
    setId: SET_ID,
    no,
    topic: String(row.Topic || '').trim(),
    word,
    meaningVi: String(row['Vietnamese meaning'] || '').trim(),
    partOfSpeech: String(row['Part of speech'] || '').trim(),
    sourceStyle,
    sourceUrl,
    createdAt: now,
    updatedAt: now,
  };
}

async function commitInBatches(db, operations) {
  let batch = db.batch();
  let count = 0;
  let committed = 0;

  for (const operation of operations) {
    operation(batch);
    count += 1;

    if (count === MAX_BATCH_SIZE) {
      await batch.commit();
      committed += count;
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
    committed += count;
  }

  return committed;
}

async function main() {
  const csvPath = resolveCsvPath();
  initFirebaseAdmin();

  const db = admin.firestore();
  const rows = readCsv(csvPath);
  const words = rows.map(normalizeRow).filter(Boolean);

  if (words.length === 0) {
    throw new Error('No valid TOEIC vocabulary rows found in CSV.');
  }

  const firstWord = words[0];
  const now = admin.firestore.FieldValue.serverTimestamp();
  const setRef = db.collection('systemVocabularySets').doc(SET_ID);

  const operations = [
    (batch) =>
      batch.set(
        setRef,
        {
          id: SET_ID,
          name: SET_NAME,
          description: SET_DESCRIPTION,
          totalWords: words.length,
          sourceStyle: firstWord.sourceStyle,
          sourceUrl: firstWord.sourceUrl,
          createdAt: now,
          updatedAt: now,
        },
        { merge: true },
      ),
    ...words.map((word) => {
      const wordRef = setRef.collection('words').doc(word.id);
      return (batch) => batch.set(wordRef, word, { merge: true });
    }),
  ];

  const committed = await commitInBatches(db, operations);
  console.log(`Imported ${words.length} words into ${SET_ID}.`);
  console.log(`Committed ${committed} Firestore write operations.`);
  console.log(`CSV: ${csvPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
