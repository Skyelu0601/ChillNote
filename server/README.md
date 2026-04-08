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
- `POST /ai/gemini` - General AI text processing


## Configuration

### Upload Limits

For production deployments with voice recording features, you need to configure upload limits at multiple layers:

- **Nginx**: Set `client_max_body_size` (recommended: 50m or higher)
- **Application**: Set `MAX_VOICE_NOTE_AUDIO_MB` in `.env` (default: 30)
- **Timeout**: Set `VOICE_NOTE_TIMEOUT_MS` in `.env` (default: 180000)

See [Upload Limits Configuration Guide](../docs/upload-limits-config.md) for detailed instructions.

### Quick Start for Production

```bash
# In your .env file
MAX_VOICE_NOTE_AUDIO_MB=50
VOICE_NOTE_TIMEOUT_MS=180000
GEMINI_API_KEY=your_gemini_api_key
```

### Gemini API Notes

- The backend sends Gemini requests to `generativelanguage.googleapis.com`.
- Use a paid Gemini API key in `GEMINI_API_KEY` for production usage.

### Deployment Layout

- Production releases live under `/root/chillnote-api/current`.
- Shared runtime env now lives at `/root/chillnote-api/shared/.env`.
- The deploy script keeps `/root/chillnote-api/current/.env` in sync with `/root/chillnote-api/shared/.env`.

```nginx
# In your Nginx config
server {
  client_max_body_size 50m;
  proxy_read_timeout 300s;
  proxy_send_timeout 300s;
  # ... other config
}
```
