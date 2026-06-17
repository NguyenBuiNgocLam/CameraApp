import cors from 'cors';
import express from 'express';
import he from 'he';
import { fetchTranscript } from 'youtube-transcript';

import { authMiddleware } from './middlewares/authMiddleware.js';

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(
  cors({
    origin: true,
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_, res) => {
  res.json({ ok: true });
});

app.post('/api/transcript', authMiddleware, async (req, res) => {
  const requestId = createRequestId();
  let videoId = null;

  try {
    const youtubeUrl = String(req.body?.youtubeUrl ?? '').trim();
    videoId = extractYouTubeVideoId(youtubeUrl);

    console.log(
      `[${requestId}] Transcript request`,
      JSON.stringify({
        uid: req.user.uid,
        videoId,
        urlType: describeYouTubeInput(youtubeUrl),
      }),
    );

    if (!videoId) {
      console.warn(
        `[${requestId}] Invalid YouTube input`,
        JSON.stringify({ inputLength: youtubeUrl.length }),
      );
      return res.status(400).json({
        error: 'Invalid YouTube URL. Please paste a valid YouTube video link.',
      });
    }

    const videoTitle = await fetchVideoTitle(youtubeUrl).catch((error) => {
      console.warn(
        `[${requestId}] Could not fetch video title`,
        JSON.stringify(formatErrorForLog(error)),
      );
      return 'YouTube video';
    });

    console.log(
      `[${requestId}] Fetching transcript`,
      JSON.stringify({ videoId }),
    );

    const transcript = await fetchTranscript(videoId);

    console.log(
      `[${requestId}] Transcript fetched`,
      JSON.stringify({
        videoId,
        cueCount: Array.isArray(transcript) ? transcript.length : null,
        resultType: Array.isArray(transcript) ? 'array' : typeof transcript,
      }),
    );

    if (!Array.isArray(transcript) || transcript.length === 0) {
      console.warn(
        `[${requestId}] Transcript unavailable or empty`,
        JSON.stringify({
          videoId,
          resultType: Array.isArray(transcript) ? 'array' : typeof transcript,
        }),
      );
      return res.status(404).json({
        error:
          'This video does not have an available transcript/caption. Please try another video.',
      });
    }

    const cues = transcript
      .map(normalizeTranscriptCue)
      .filter((cue) => cue.text.length > 0)
      .sort((a, b) => a.startTime - b.startTime);

    if (cues.length === 0) {
      console.warn(
        `[${requestId}] Transcript normalized to zero cues`,
        JSON.stringify({ videoId, rawCueCount: transcript.length }),
      );
      return res.status(404).json({
        error:
          'This video transcript is empty. Please try a video with captions.',
      });
    }

    const segments = buildDictationSegments(cues);
    console.log(
      `[${requestId}] Transcript response ready`,
      JSON.stringify({
        videoId,
        cueCount: cues.length,
        segmentCount: segments.length,
        title: videoTitle,
      }),
    );

    res.json({
      videoTitle,
      segments,
    });
  } catch (error) {
    const message = String(error?.message ?? error);
    const lower = message.toLowerCase();
    const noTranscript =
      lower.includes('transcript') ||
      lower.includes('caption') ||
      lower.includes('disabled') ||
      lower.includes('not available');

    console.error(
      `[${requestId}] Transcript request failed`,
      JSON.stringify({
        videoId,
        statusCode: noTranscript ? 404 : 500,
        error: formatErrorForLog(error),
      }),
    );

    res.status(noTranscript ? 404 : 500).json({
      error: noTranscript
        ? 'This video does not have an available transcript/caption. Please try another video.'
        : 'Cannot fetch transcript right now. Please try again later.',
    });
  }
});

app.use((error, _, res, next) => {
  if (error instanceof SyntaxError && 'body' in error) {
    return res.status(400).json({
      error: 'Invalid JSON body. Please send a valid youtubeUrl value.',
    });
  }

  return next(error);
});

app.use((_, res) => {
  res.status(404).json({ error: 'Endpoint not found.' });
});

app.listen(port, () => {
  console.log(`YouTube Dictation backend is running on http://localhost:${port}`);
});

function extractYouTubeVideoId(input) {
  if (!input) return null;

  try {
    const url = new URL(input);
    const host = url.hostname.replace(/^www\./, '').replace(/^m\./, '');

    if (host === 'youtu.be') {
      return normalizeVideoId(url.pathname.split('/').filter(Boolean)[0]);
    }

    if (!['youtube.com', 'youtube-nocookie.com'].includes(host)) {
      return null;
    }

    if (url.searchParams.has('v')) {
      return normalizeVideoId(url.searchParams.get('v'));
    }

    const parts = url.pathname.split('/').filter(Boolean);
    const knownPrefixes = new Set(['embed', 'shorts', 'live', 'watch']);
    if (parts.length >= 2 && knownPrefixes.has(parts[0])) {
      return normalizeVideoId(parts[1]);
    }

    return normalizeVideoId(parts[0]);
  } catch (_) {
    return normalizeVideoId(input);
  }
}

function normalizeVideoId(value) {
  const id = String(value ?? '').trim();
  return /^[a-zA-Z0-9_-]{11}$/.test(id) ? id : null;
}

function createRequestId() {
  return Math.random().toString(36).slice(2, 8);
}

function describeYouTubeInput(input) {
  try {
    const url = new URL(input);
    return url.hostname.replace(/^www\./, '').replace(/^m\./, '');
  } catch (_) {
    return normalizeVideoId(input) ? 'video_id' : 'invalid_or_partial';
  }
}

function formatErrorForLog(error) {
  const cause = error?.cause;

  return {
    name: error?.name ?? null,
    message: String(error?.message ?? error),
    code: error?.code ?? cause?.code ?? null,
    status: error?.status ?? error?.statusCode ?? cause?.status ?? null,
    stack: trimStack(error?.stack),
  };
}

function trimStack(stack) {
  if (!stack) return null;
  return String(stack).split('\n').slice(0, 5).join(' | ');
}

async function fetchVideoTitle(youtubeUrl) {
  const response = await fetch(
    `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(
      youtubeUrl,
    )}`,
  );

  if (!response.ok) return 'YouTube video';

  const data = await response.json();
  return cleanText(data?.title) || 'YouTube video';
}

function normalizeTranscriptCue(cue) {
  const start = cue.offset ?? cue.start ?? cue.startTime ?? 0;
  const duration = cue.duration ?? cue.dur ?? 0;

  return {
    startTime: normalizeSeconds(start),
    duration: Math.max(normalizeSeconds(duration), 0),
    text: cleanText(cue.text ?? cue.caption ?? ''),
  };
}

function normalizeSeconds(value) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) return 0;

  // youtube-transcript currently returns milliseconds. Keep this tolerant in
  // case another source returns seconds in the future.
  return number > 1000 ? number / 1000 : number;
}

function buildDictationSegments(cues) {
  const segments = [];
  let group = [];
  let groupStart = 0;
  let groupEnd = 0;

  for (const cue of cues) {
    if (group.length === 0) {
      groupStart = cue.startTime;
      groupEnd = cue.startTime + cue.duration;
    }

    group.push(cue);
    groupEnd = Math.max(groupEnd, cue.startTime + cue.duration);

    const text = group.map((item) => item.text).join(' ');
    const duration = groupEnd - groupStart;
    const shouldClose =
      duration >= 10 ||
      (duration >= 5 && /[.!?]"?$/.test(text.trim())) ||
      wordCount(text) >= 24;

    if (shouldClose) {
      segments.push(createSegment(segments.length, group, groupStart, groupEnd));
      group = [];
    }
  }

  if (group.length > 0) {
    segments.push(createSegment(segments.length, group, groupStart, groupEnd));
  }

  return segments;
}

function createSegment(index, group, startTime, endTime) {
  return {
    index,
    startTime: round(startTime),
    duration: round(Math.min(Math.max(endTime - startTime, 1), 10)),
    text: cleanText(group.map((item) => item.text).join(' ')),
    translationVi: '',
  };
}

function cleanText(value) {
  return he
    .decode(String(value ?? ''))
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function wordCount(text) {
  return cleanText(text).split(/\s+/).filter(Boolean).length;
}

function round(value) {
  return Math.round(value * 10) / 10;
}
