# ChillScript Backend

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
   - `GEMINI_MODEL` (optional, defaults to `gemini-3.1-flash-lite`)
5) Set Creem billing config if web checkout is enabled:
   - `CREEM_API_KEY`
   - `CREEM_WEBHOOK_SECRET`
   - `CREEM_MONTHLY_PRODUCT_ID`
   - `CREEM_YEARLY_PRODUCT_ID`
   - `WEB_APP_BASE_URL` (for checkout success redirects)
   - `CREEM_TEST_MODE=true` for Creem test mode, or set `CREEM_API_BASE_URL` directly

6) Create schema

```bash
npx prisma migrate dev --name init
```

7) Run dev server

```bash
npm run dev
```

## Endpoints

- `GET /health`
- `POST /auth/apple`
- `POST /auth/refresh`
- `POST /sync`
  - Optional query: `?since=ISO8601` to return only changes since that time
- `POST /billing/creem/checkout` - Create a Creem checkout session for the signed-in web user
- `POST /webhooks/creem` - Receive Creem subscription lifecycle webhooks
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
- `MEDIA_LINK_YTDLP_BIN`: Optional default path to `yt-dlp` for YouTube, Instagram, and TikTok when no TikTok-specific override is configured.
- `MEDIA_LINK_TIKTOK_YTDLP_BIN`: Optional TikTok-only `yt-dlp` path. This allows TikTok to temporarily use a pinned working version while YouTube and Instagram stay on the current version.
- `MEDIA_LINK_FFMPEG_BIN`: Optional path to `ffmpeg` for video-to-audio extraction.
- `MEDIA_LINK_TRANSCRIPT_EXTRACT_AUDIO`: Defaults to `true`. Extracts audio before transcription when possible.
- `MEDIA_LINK_TRANSCRIPT_MAX_MEDIA_MB`: Max media size accepted for transcription. Defaults to `100`.
- `MEDIA_LINK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS`: Media download timeout. Defaults to `90000`.
- `MEDIA_LINK_TRANSCRIPT_TIMEOUT_MS`: Gemini transcription timeout. Defaults to `180000`.
- `MEDIA_LINK_APIFY_TOKEN`: Optional Apify API token. When set, TikTok media-fetch failures automatically fall back to Apify after `yt-dlp` fails.
- `MEDIA_LINK_APIFY_FALLBACK`: Defaults to `true`. Set to `false` to disable the paid Apify fallback without removing the token.
- `MEDIA_LINK_APIFY_ACTOR_ID`: Defaults to `clockworks~tiktok-video-scraper`.
- `MEDIA_LINK_APIFY_TIMEOUT_MS`: Total timeout for an Apify run and media download. Defaults to `150000`.
- `MEDIA_LINK_APIFY_MAX_TOTAL_CHARGE_USD`: Hard per-run charge cap passed to Apify. Defaults to `0.10`.

- `TIKTOK_TRANSCRIPT_RESOLVER_URL`: Optional external resolver endpoint that accepts `{ "url": "...", "videoID": "..." }` and returns media for transcription.
- `TIKTOK_TRANSCRIPT_RESOLVER_TOKEN`: Optional bearer token for the resolver.
- `TIKTOK_TRANSCRIPT_USE_YTDLP`: Defaults to `true`. When enabled, the worker tries `yt-dlp` on the server if no resolver is configured.
- `TIKTOK_YTDLP_BIN`: Legacy TikTok-only alias for `MEDIA_LINK_TIKTOK_YTDLP_BIN`.
- `TIKTOK_FFMPEG_BIN`: Optional path to `ffmpeg` for video-to-audio extraction.
- `TIKTOK_TRANSCRIPT_EXTRACT_AUDIO`: Defaults to `true`. Extracts audio before transcription when possible.
- `TIKTOK_TRANSCRIPT_MAX_MEDIA_MB`: Max media size accepted for transcription. Defaults to `100`.
- `TIKTOK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS`: Media download timeout. Defaults to `90000`.
- `TIKTOK_TRANSCRIPT_TIMEOUT_MS`: Gemini transcription timeout. Defaults to `180000`.

The `TIKTOK_*` variables remain supported as fallbacks for backward compatibility.

For YouTube, TikTok, and Instagram/Reels, the worker first tries to read available captions or auto-captions through `yt-dlp`, then falls back to media download and transcription. This avoids the common case where a media download exceeds `MEDIA_LINK_TRANSCRIPT_MAX_MEDIA_MB`.

When `MEDIA_LINK_APIFY_TOKEN` (or the compatible `APIFY_TOKEN` / `TIKTOK_APIFY_TOKEN`) is configured, only TikTok fetch failures fall back to Apify. Each run is limited to one paid result and the configured charge cap. The worker downloads protected media with backend-only authorization, then best-effort deletes the temporary Apify video store, dataset, input store, request queue, and run record. The token is never returned to the iOS app or sent to a TikTok CDN host.

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
# Google Play subscription verification

Android subscription verification uses the Google Play Developer API and requires these production environment variables:

```text
GOOGLE_PLAY_PACKAGE_NAME=com.sponteoai.chillscript
GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL=service-account@project.iam.gserviceaccount.com
GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

The service account must be invited in Google Play Console and granted permission to view orders and manage subscriptions. Never commit the private key.

Durable token ownership, acknowledgement retries, deployment checks, and the
current RTDN limitation are documented in [GOOGLE_PLAY_BILLING.md](./GOOGLE_PLAY_BILLING.md).
