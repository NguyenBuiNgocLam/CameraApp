# Vocabulary Admin Web

React + Vite admin web for managing system vocabulary in Cloud Firestore.

## Features

- Firebase Authentication email/password login.
- Admin access check with `admins/{uid}`.
- Dashboard statistics for vocabulary sets and words.
- Vocabulary set create, edit, delete.
- Word create, edit, delete.
- Search words by `word`, `meaningVi`, or `topic`.
- Filter words by topic.
- CSV import with preview, validation, batch writes, merge updates, and `totalWords` refresh.

## Firestore Collections

The admin web uses the existing Flutter app structure:

```text
systemVocabularySets/{setId}
systemVocabularySets/{setId}/words/{wordId}
users/{uid}/systemVocabularyProgress
admins/{uid}
```

Admin documents must be created manually in Firebase Console:

```json
{
  "uid": "firebase-auth-uid",
  "email": "admin@example.com",
  "role": "admin",
  "createdAt": "server timestamp"
}
```

Client code cannot create admin users.

## Environment

Create `admin-web/.env` from `.env.example`:

```bash
cp .env.example .env
```

Fill in Firebase Web config:

```text
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=
VITE_FIREBASE_STORAGE_BUCKET=
VITE_FIREBASE_MESSAGING_SENDER_ID=
VITE_FIREBASE_APP_ID=
```

Do not commit `.env`.

`VITE_FIREBASE_APP_ID` is recommended when you create a Web app in Firebase Console, but the admin web can run Firebase Auth and Firestore without it.

## Run Locally

```bash
cd admin-web
npm install
npm run dev
```

Open the Vite URL, usually:

```text
http://localhost:5173/login
```

## Build

```bash
npm run build
```

## CSV Import Format

CSV headers must match:

```text
No,Topic,Vocabulary,Part of speech,Vietnamese meaning,Source style,Source URL
```

Mapping:

- `No` -> `no`
- `Topic` -> `topic`
- `Vocabulary` -> `word`
- `Part of speech` -> `partOfSpeech`
- `Vietnamese meaning` -> `meaningVi`
- `Source style` -> `sourceStyle`
- `Source URL` -> `sourceUrl`

The generated `wordId` format is:

```text
001_abide_by
```

Import uses Firestore batch writes in chunks below 500 operations. Existing `wordId` documents are updated with merge mode.

## Firestore Rules

The root `firestore.rules` file allows signed-in users to read system vocabulary and only admins to write system vocabulary. Deploy rules with your normal Firebase workflow.
