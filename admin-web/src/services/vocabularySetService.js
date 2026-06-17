import {
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { db } from '../firebase';

const SETS_COLLECTION = 'systemVocabularySets';

export function vocabularySetsRef() {
  return collection(db, SETS_COLLECTION);
}

export function vocabularySetRef(setId) {
  return doc(db, SETS_COLLECTION, setId);
}

export function wordsCollectionRef(setId) {
  return collection(db, SETS_COLLECTION, setId, 'words');
}

export async function getVocabularySets() {
  const snapshot = await getDocs(query(vocabularySetsRef(), orderBy('updatedAt', 'desc')));
  return snapshot.docs.map((setDocSnap) => ({
    id: setDocSnap.id,
    ...setDocSnap.data(),
  }));
}

export async function getLatestVocabularySets(count = 5) {
  const snapshot = await getDocs(
    query(vocabularySetsRef(), orderBy('updatedAt', 'desc'), limit(count)),
  );
  return snapshot.docs.map((setDocSnap) => ({
    id: setDocSnap.id,
    ...setDocSnap.data(),
  }));
}

export async function getVocabularySet(setId) {
  const snapshot = await getDoc(vocabularySetRef(setId));

  if (!snapshot.exists()) {
    return null;
  }

  return {
    id: snapshot.id,
    ...snapshot.data(),
  };
}

export async function createVocabularySet(values) {
  const setId = values.id.trim();
  const ref = vocabularySetRef(setId);
  const existing = await getDoc(ref);

  if (existing.exists()) {
    throw new Error('Vocabulary set id already exists.');
  }

  await setDoc(ref, {
    id: setId,
    name: values.name.trim(),
    description: values.description.trim(),
    sourceStyle: values.sourceStyle.trim(),
    sourceUrl: values.sourceUrl.trim(),
    totalWords: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}

export async function updateVocabularySet(setId, values) {
  await updateDoc(vocabularySetRef(setId), {
    name: values.name.trim(),
    description: values.description.trim(),
    sourceStyle: values.sourceStyle.trim(),
    sourceUrl: values.sourceUrl.trim(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteVocabularySet(setId) {
  const wordsSnapshot = await getDocs(wordsCollectionRef(setId));
  let batch = writeBatch(db);
  let operations = 0;

  for (const wordDoc of wordsSnapshot.docs) {
    batch.delete(wordDoc.ref);
    operations += 1;

    if (operations === 450) {
      await batch.commit();
      batch = writeBatch(db);
      operations = 0;
    }
  }

  if (operations > 0) {
    await batch.commit();
  }

  await deleteDoc(vocabularySetRef(setId));
}

export async function getVocabularySetStats() {
  const sets = await getVocabularySets();
  const totalSets = sets.length;
  const totalWords = sets.reduce((sum, item) => sum + Number(item.totalWords || 0), 0);
  const toeicSet = sets.find((item) => {
    const target = `${item.id || ''} ${item.name || ''}`.toLowerCase();
    return target.includes('toeic') && target.includes('600');
  });

  return {
    totalSets,
    totalWords,
    toeic600Words: Number(toeicSet?.totalWords || 0),
    latestSets: sets.slice(0, 5),
  };
}

export async function refreshVocabularySetTotalWords(setId) {
  const countSnapshot = await getCountFromServer(wordsCollectionRef(setId));
  const totalWords = countSnapshot.data().count;

  await updateDoc(vocabularySetRef(setId), {
    totalWords,
    updatedAt: serverTimestamp(),
  });

  return totalWords;
}
