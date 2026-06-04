# YouTube Dictation Backend

Small Express API for fetching existing YouTube transcript/caption data for dictation practice.

This backend does not download video or audio. It only reads transcript/caption data that is already available for the YouTube video.

## Install

```bash
cd backend
npm install
```

## Run

```bash
npm start
```

Default URL:

```text
http://localhost:4000
```

Optional custom port:

```bash
$env:PORT=3000; npm start
```

## Endpoints

### Health Check

```bash
curl http://localhost:4000/health
```

Expected response:

```json
{
  "ok": true
}
```

### Get Transcript

```powershell
curl.exe -X POST http://localhost:4000/api/transcript `
  -H 'Content-Type: application/json' `
  -d '{"youtubeUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

macOS/Linux:

```bash
curl -X POST http://localhost:4000/api/transcript \
  -H "Content-Type: application/json" \
  -d '{"youtubeUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

Successful response shape:

```json
{
  "videoTitle": "Video title",
  "segments": [
    {
      "index": 0,
      "startTime": 12.5,
      "duration": 5.2,
      "text": "A transcript segment.",
      "translationVi": ""
    }
  ]
}
```

If the URL is invalid:

```json
{
  "error": "Invalid YouTube URL. Please paste a valid YouTube video link."
}
```

If the video has no available transcript/caption:

```json
{
  "error": "This video does not have an available transcript/caption. Please try another video."
}
```
