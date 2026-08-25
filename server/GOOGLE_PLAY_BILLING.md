# Google Play Billing backend

## What is production-ready in this repository

`POST /subscription/google/verify` verifies subscriptions with the Google Play
Developer API. Every purchase token is persisted as the primary key of
`GooglePlayPurchase`, so ownership cannot move between users and repeated
requests are idempotent.

An unacknowledged purchase does not update the user's Pro projection. The
server first acknowledges it, then atomically marks the purchase entitled and
updates `User`. Transient network, HTTP 408/429, and Google 5xx failures are
stored with exponential backoff. A process-local worker polls those durable
rows; a database lease prevents two server replicas from completing the same
attempt concurrently. HTTP 401/403 and other terminal acknowledgement failures
remain persisted but are not retried forever. A client retry can resume them
after configuration is repaired.

Required environment variables:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`
- Optional: `GOOGLE_PLAY_BILLING_WORKER_INTERVAL_MS` (minimum 30 seconds)

The Play service account needs the minimum Google Play Console permission
required to read and acknowledge subscriptions. Purchase tokens and Google
response bodies must never be written to application logs.

## RTDN is not enabled by this code

Real-time developer notifications (RTDN) require Google Cloud Pub/Sub and
deployment-specific authentication. No public RTDN route is registered here,
and the application must not be described as receiving production lifecycle
notifications until the following external configuration and verification are
complete:

1. Create a dedicated Pub/Sub topic and subscription in the same Google Cloud
   project used by Play Console, then grant the documented Google Play service
   account publisher permission on only that topic.
2. Configure an authenticated push subscription. Verify the Google-signed OIDC
   token's signature, issuer, audience, and intended service account before
   parsing a message. Do not accept a shared-secret-only or unauthenticated
   internet endpoint.
3. Persist Pub/Sub `messageId` with a unique constraint before handling it, so
   redelivery is idempotent. Return a non-2xx response when durable handling did
   not complete, allowing Pub/Sub to retry.
4. Treat an RTDN payload only as a signal. Decode the purchase token, look up
   its fixed owner, and fetch the current subscription from the Google Play
   Developer API. Never grant or revoke entitlement directly from notification
   fields.
5. Add reconciliation for expired, revoked, on-hold, paused, superseded, and
   refunded purchases. Recalculate the user's final entitlement across Google,
   Apple, Creem, and invite grants instead of clearing unrelated benefits.
6. Configure a dead-letter topic, retention, alerting, and replay tests before
   enabling the Play Console topic in production.

Until RTDN is deployed, acknowledgement state is eventually consistent through
the durable retry worker, but cancellation/refund state changes are learned only
when the purchase is verified again. This limitation should be tracked as a
separate release-hardening item.
