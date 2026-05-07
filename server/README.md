# ChillNote Backend

## Setup

1) Copy env file

```bash
cp .env.example .env
```

2) Update `DATABASE_URL` to your PostgreSQL connection string.
3) Set Apple config for token exchange:
   - `APPLE_CLIENT_ID` (iOS bundle ID)
   - `APPLE_TEAM_ID`
   - `APPLE_KEY_ID`
   - `APPLE_PRIVATE_KEY` (p8 content, use `\n` for newlines)
   - `APPLE_REDIRECT_URI` (optional)
4) Set AI config:
   - `GEMINI_API_KEY`
   - `GEMINI_MODEL` (optional, defaults to `gemini-3.1-flash-lite-preview`)

5) Create schema

```bash
npx prisma migrate dev --name init
```

6) Run dev server

```bash
npm run dev
```

## Endpoints

- `GET /health`
- `POST /auth/apple`
- `POST /auth/refresh`
- `POST /sync`
  - Optional query: `?since=ISO8601` to return only changes since that time
- `POST /ai/voice-note` - Voice transcription only (no polishing)
- `POST /ai/media-link-transcript` - TikTok / YouTube / Instagram link transcription with backend worker
- `POST /ai/tiktok-transcript` - Backward-compatible TikTok-only alias
- `POST /ai/gemini` - General AI text processing


## Configuration

### Upload Limits

For production deployments with voice recording features, you need to configure upload limits at multiple layers:

- **Nginx**: Set `client_max_body_size` (recommended: 150m or higher)
- **Application**: Set `MAX_VOICE_NOTE_AUDIO_MB` in `.env` (default: 100)
- **AI JSON parser**: Set `AI_JSON_LIMIT` in `.env` (default: 150mb)
- **Timeout**: Set `VOICE_NOTE_TIMEOUT_MS` in `.env` (default: 180000)

See [Upload Limits Configuration Guide](../docs/upload-limits-config.md) for detailed instructions.

### Quick Start for Production

```bash
# In your .env file
MAX_VOICE_NOTE_AUDIO_MB=100
AI_JSON_LIMIT=150mb
VOICE_NOTE_TIMEOUT_MS=180000
GEMINI_API_KEY=your_gemini_api_key
```

### Gemini API Notes

- The backend sends Gemini requests to `generativelanguage.googleapis.com`.
- Use a paid Gemini API key in `GEMINI_API_KEY` for production usage.

### Media Link Transcript Worker

The media-link worker keeps TikTok / YouTube / Instagram transcription handling on the backend.

Recommended environment variables:

- `MEDIA_LINK_TRANSCRIPT_RESOLVER_URL`: Optional external resolver endpoint that accepts `{ "url": "...", "videoID": "...", "platform": "..." }` and returns media for transcription.
- `MEDIA_LINK_TRANSCRIPT_RESOLVER_TOKEN`: Optional bearer token for the resolver.
- `MEDIA_LINK_TRANSCRIPT_USE_YTDLP`: Defaults to `true`. When enabled, the worker tries `yt-dlp` on the server if no resolver is configured.
- `MEDIA_LINK_YTDLP_BIN`: Optional path to `yt-dlp`.
- `MEDIA_LINK_FFMPEG_BIN`: Optional path to `ffmpeg` for video-to-audio extraction.
- `MEDIA_LINK_TRANSCRIPT_EXTRACT_AUDIO`: Defaults to `true`. Extracts audio before transcription when possible.
- `MEDIA_LINK_TRANSCRIPT_MAX_MEDIA_MB`: Max media size accepted for transcription. Defaults to `25`.
- `MEDIA_LINK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS`: Media download timeout. Defaults to `90000`.
- `MEDIA_LINK_TRANSCRIPT_TIMEOUT_MS`: Gemini transcription timeout. Defaults to `180000`.

- `TIKTOK_TRANSCRIPT_RESOLVER_URL`: Optional external resolver endpoint that accepts `{ "url": "...", "videoID": "..." }` and returns media for transcription.
- `TIKTOK_TRANSCRIPT_RESOLVER_TOKEN`: Optional bearer token for the resolver.
- `TIKTOK_TRANSCRIPT_USE_YTDLP`: Defaults to `true`. When enabled, the worker tries `yt-dlp` on the server if no resolver is configured.
- `TIKTOK_YTDLP_BIN`: Optional path to `yt-dlp`.
- `TIKTOK_FFMPEG_BIN`: Optional path to `ffmpeg` for video-to-audio extraction.
- `TIKTOK_TRANSCRIPT_EXTRACT_AUDIO`: Defaults to `true`. Extracts audio before transcription when possible.
- `TIKTOK_TRANSCRIPT_MAX_MEDIA_MB`: Max media size accepted for transcription. Defaults to `25`.
- `TIKTOK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS`: Media download timeout. Defaults to `90000`.
- `TIKTOK_TRANSCRIPT_TIMEOUT_MS`: Gemini transcription timeout. Defaults to `180000`.

The `TIKTOK_*` variables remain supported as fallbacks for backward compatibility.

For YouTube, the worker first tries to read available captions or auto-captions through `yt-dlp`, then falls back to media download and transcription. This avoids the common case where a YouTube audio download exceeds `MEDIA_LINK_TRANSCRIPT_MAX_MEDIA_MB`.

If neither `MEDIA_LINK_TRANSCRIPT_RESOLVER_URL` nor a working `yt-dlp` binary is available, the endpoint will return `available: false` and the iOS app will fall back to a metadata-only link note.

### Deployment Layout

- Production releases live under `/root/chillnote-api/current`.
- Shared runtime env now lives at `/root/chillnote-api/shared/.env`.
- The deploy script keeps `/root/chillnote-api/current/.env` in sync with `/root/chillnote-api/shared/.env`.

```nginx
# In your Nginx config
server {
  client_max_body_size 150m;
  proxy_read_timeout 300s;
  proxy_send_timeout 300s;
  # ... other config
}
```
