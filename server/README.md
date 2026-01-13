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

4) Create schema

```bash
npx prisma migrate dev --name init
```

5) Run dev server

```bash
npm run dev
```

## Endpoints

- `GET /health`
- `POST /auth/apple`
- `POST /auth/refresh`
- `POST /sync`
  - Optional query: `?since=ISO8601` to return only changes since that time
- `POST /media/upload` (multipart `file`)
- `GET /media/:id` (requires auth)

Uploads are stored on disk under `server/uploads/<userId>/`.
