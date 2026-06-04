# AI English Vocabulary Camera App

Flutter portfolio app for learning English vocabulary from camera images.

## Features

- Firebase Authentication login/register/logout
- Firestore user, vocabulary, and quiz result sync
- Hive local/offline vocabulary storage
- Camera/gallery image picking
- Gemini Vision image analysis
- Text-to-speech pronunciation
- Vocabulary search, favorite, delete
- Quiz generated from saved vocabulary
- Light/dark mode

## Setup

```bash
flutter pub get
```

Create `.env` in the project root:

```env
GEMINI_API_KEY=your_api_key_here
```

For Firebase Android, create a Firebase project, add Android app package:

```text
com.nhanlam.ai_vocabulary_camera
```

Download `google-services.json` and place it at:

```text
android/app/google-services.json
```

Then run:

```bash
flutter clean
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --debug
flutter build apk --release
```

Debug APK:

```text
build/app/outputs/flutter-apk/app-debug.apk
```
