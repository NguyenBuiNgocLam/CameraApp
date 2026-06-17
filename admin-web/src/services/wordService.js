import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { db } from '../firebase';
import { createWordId } from '../utils/slugify';
import { toNumber } from '../utils/formatters';
import { refreshVocabularySetTotalWords, wordsCollectionRef } from './vocabularySetService';

export async function getWords(setId) {
  const snapshot = await getDocs(query(wordsCollectionRef(setId), orderBy('no', 'asc')));
  return snapshot.docs.map((wordDoc) => ({
    id: wordDoc.id,
    ...wordDoc.data(),
  }));
}

export async function addWord(setId, values) {
  const wordId = createWordId(values.no, values.word);

  if (!wordId) {
    throw new Error('Word id could not be created. Please check No and Word.');
  }

  const wordRef = doc(db, 'systemVocabularySets', setId, 'words', wordId);
  const existing = await getDoc(wordRef);

  if (existing.exists()) {
    throw new Error('Word id already exists. Change No or Word before adding.');
  }

  await setDoc(wordRef, {
    id: wordId,
    setId,
    no: toNumber(values.no),
    topic: values.topic.trim(),
    word: values.word.trim(),
    meaningVi: values.meaningVi.trim(),
    partOfSpeech: values.partOfSpeech.trim(),
    sourceStyle: values.sourceStyle.trim(),
    sourceUrl: values.sourceUrl.trim(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  await refreshVocabularySetTotalWords(setId);
}

export async function updateWord(setId, wordId, values) {
  await updateDoc(doc(db, 'systemVocabularySets', setId, 'words', wordId), {
    no: toNumber(values.no),
    topic: values.topic.trim(),
    word: values.word.trim(),
    meaningVi: values.meaningVi.trim(),
    partOfSpeech: values.partOfSpeech.trim(),
    sourceStyle: values.sourceStyle.trim(),
    sourceUrl: values.sourceUrl.trim(),
    updatedAt: serverTimestamp(),
  });
}

export async function deleteWord(setId, wordId) {
  await deleteDoc(doc(db, 'systemVocabularySets', setId, 'words', wordId));
  await refreshVocabularySetTotalWords(setId);
}
