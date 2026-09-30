# Request authentication

Protected routes keep the existing `Authorization: Bearer <access token>` contract for iOS and Android.

`auth.ts` verifies Supabase JWT signatures through `getClaims()`, which caches the project's public signing keys. The live project uses ES256. This removes the `/auth/v1/user` HTTP request and its gateway/Auth logs from the normal request path. Legacy symmetric tokens retain the Supabase SDK's remote verification fallback.

After signature verification, `authSession.ts` uses the existing server-only Prisma connection to look up the signed `session_id` and user ID in `auth.sessions` and `auth.users`. Every request checks that the session exists, has not passed `not_after`, and belongs to a user who has not been deleted or banned. These results are not cached, so revocation works across backend instances. Only ID, email and creation date are selected; checkout and welcome notifications continue receiving current user data.

The database role in `DATABASE_URL` must be able to read these two Auth tables. Do not grant access to mobile/API roles or expose a new RPC. A database lookup failure rejects the request, matching the previous fail-closed behavior of Auth verification.

No signing-key rotation, schema migration, mobile update or synchronization-frequency change is needed. Before deployment, verify the configured server database role can run the lookup. After deployment, compare `/auth/v1/user` event volume and API latency/error rates over comparable traffic windows; local tests cannot establish production latency or billing savings.

Validation: `npm run build` and `npx --no-install tsx --test src/auth.test.ts src/accountDeletion.test.ts src/appNotifications.test.ts src/subscriptionVerification.test.ts`.

For the real PostgreSQL predicate check, run `AUTH_DATABASE_TEST=1 node --import tsx --test src/authSession.test.ts`. It requires the backend database connection and executes the production lookup against read-only `VALUES` fixtures covering session ownership, revocation, expiry, deletion and bans. It does not modify or read real user/session rows.
