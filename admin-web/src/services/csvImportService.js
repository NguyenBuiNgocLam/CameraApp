import { doc, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';
import { db } from '../firebase';
import { refreshVocabularySetTotalWords } from './vocabularySetService';

const MAX_BATCH_OPERATIONS = 450;

export async function importVocabularyRows(setId, rows) {
  if (!setId) {
    throw new Error('Please select a vocabulary set.');
  }

  if (rows.length === 0) {
    throw new Error('No valid rows to import.');
  }

  let batch = writeBatch(db);
  let operations = 0;
  let imported = 0;

  for (const row of rows) {
    const wordRef = doc(db, 'systemVocabularySets', setId, 'words', row.id);

    batch.set(
      wordRef,
      {
        id: row.id,
        setId,
        no: row.no,
        topic: row.topic,
        word: row.word,
        meaningVi: row.meaningVi,
        partOfSpeech: row.partOfSpeech,
        sourceStyle: row.sourceStyle,
        sourceUrl: row.sourceUrl,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    operations += 1;
    imported += 1;

    if (operations === MAX_BATCH_OPERATIONS) {
      await batch.commit();
      batch = writeBatch(db);
      operations = 0;
    }
  }

  if (operations > 0) {
    await batch.commit();
  }

  const totalWords = await refreshVocabularySetTotalWords(setId);

  return {
    imported,
    totalWords,
  };
}
