# RevenueCat rollout runbook

RevenueCat is the authority for Apple subscription verification. The legacy
Apple endpoint remains as a compatibility URL, but no longer trusts client
transaction metadata or writes an independent Apple Pro grant. Google Play's
server-verified purchase path remains supported.

## 1. RevenueCat project

1. Add the existing App Store app (`com.sponteoai.chillnote`) and Google Play app
   (`com.sponteoai.chillscript`) to the same RevenueCat project. Do not create
   new store product IDs or change either application identifier.
2. Import `com.chillnote.pro.weekly` and `com.chillnote.pro.yearly`. Keep
   `com.chillnote.pro.monthly` attached for historical subscribers, but do not
   put the retired monthly product in the current offering.
3. Create one entitlement whose identifier is exactly `pro`, and attach all
   recognized subscription products to it.
4. Create and publish a current offering containing weekly and yearly packages.
5. Connect the App Store in-app-purchase key and Google Play service account.
   Route App Store server notifications and Google Play Pub/Sub notifications
   to RevenueCat, then use each dashboard's test-notification function.

## 2. Client keys

- iOS: put the public `appl_...` SDK key in the existing
  `REVENUECAT_IOS_API_KEY` build setting / Info.plist substitution.
- Android: set CI variable `CHILLSCRIPT_REVENUECAT_ANDROID_API_KEY`, or set
  `chillscript.revenuecat.androidApiKey=goog_...` in the ignored
  `android/local.properties` file for local builds.

Both apps identify customers with the existing authenticated backend user ID.
The public SDK keys are safe to ship in their corresponding apps; server secret
keys are not.

## 3. Backend and webhook

Apply the Prisma migration, then configure:

```text
REVENUECAT_API_KEY=<server-side v1 secret key>
REVENUECAT_ENTITLEMENT_ID=pro
REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer <a long random value>
REVENUECAT_WEBHOOK_HMAC_SECRET=<RevenueCat signing secret>
REVENUECAT_ALLOWED_APP_IDS=<ios app id>,<android app id>
```

Create a RevenueCat webhook pointing to:

```text
https://api.chillnoteai.com/webhooks/revenuecat
```

Copy the exact authorization value above into the webhook configuration, enable
HMAC signing, and store its one-time signing secret in the server environment.
Send a dashboard test event and confirm a successful response before shipping.

## 4. Existing iOS subscribers

Perform the server-side history import before releasing the RevenueCat-enabled
iOS build. It is idempotent and the first command is a read-only dry run:

```bash
cd server
APPLE_IAP_KEY_PATH=/secure/path/SubscriptionKey.p8 \
  npm run migrate:revenuecat:ios-history

APPLE_IAP_KEY_PATH=/secure/path/SubscriptionKey.p8 \
REVENUECAT_PUBLIC_API_KEY_FILE=/secure/path/revenuecat-ios-key.txt \
  npm run migrate:revenuecat:ios-history -- --commit
```

Review the summary before continuing: failed imports and failed customer
verifications must be zero. Historical Apple columns remain available for audit,
but `subscriptionProvider=apple` is no longer an authorization source. Existing
Apple purchases must be present in RevenueCat before deploying the hardened
verifier. A missing RevenueCat key or provider failure returns 503 from the
verification endpoints; it never grants Pro from client metadata.

The existing client's legacy `syncPurchases` heuristic must not be relied on for
this cutover: unverified Apple projections no longer make a user Pro. Verify the
server-side history import and refresh the RevenueCat entitlement snapshots first.
An old client without RevenueCat can still refresh an already-imported purchase
through `/subscription/verify`; metadata-only purchases not yet known to RevenueCat
cannot be activated by that compatibility endpoint.

## 5. Release verification

Use App Store sandbox/TestFlight and a Google Play internal-testing build to
verify weekly and yearly purchase, restore, renewal, cancellation, expiration,
pending Google payment, app reinstall, and switching between two accounts.

For each scenario confirm all three views agree:

- the app's Pro state;
- `GET /subscription/status` on the backend;
- the customer and `pro` entitlement in RevenueCat.

Release gradually and alert on webhook 401/403/503 responses and failed
RevenueCat customer lookups.

## 6. Subscription hardening (2026-09-13)

- Apply `20260913120000_revenuecat_transaction_owner` before starting the new
  server. It adds a nullable RevenueCat v1 transaction ID and a unique store/ID
  constraint; it does not delete existing data or alter historical identifiers.
- Restart all backend instances after deployment. Pro authorization reads current
  database state instead of a process-local Pro cache.
- Refresh existing RevenueCat snapshots before testing transfer. Old rows have
  a null transaction ID until refreshed; TRANSFER webhooks reconcile every source
  and destination even when those old rows have no transaction ID.
- Both `/subscription/verify` and `/subscription/revenuecat/sync` fetch the
  authenticated user's customer from RevenueCat. Client fields including
  `expiresDate`, `receiptData`, `transactionId`, and a supplied user ID never grant
  membership. The response retains `success`, `tier`, `expiresAt`, and
  `activeProductId` for shipped iOS and Android clients.
- Restore claims the verified store transaction and releases the previous
  account in one database transaction. Revoked Apple legacy values cannot
  override this. Google Play and Creem grants are preserved independently.
- A TRANSFER webhook refreshes all `transferred_from`, `transferred_to`, and
  alias users, not just its first matching account. Provider failures roll back
  the batch and return an error for retry.
- `/invite/me`, `/invite/bind`, and the invitation reward implementation are
  removed. Historical invite tables and migration records remain for audit.
  Initial free credits are unchanged.

Before production rollout, test a real sandbox purchase with two application
accounts, restore/transfer in both directions, expiration, and a RevenueCat
outage. Confirm old and new clients agree with the backend after refreshing.
Local unit tests do not confirm the live RevenueCat restore configuration or
that production history has been imported.

References: [RevenueCat customer response](https://www.revenuecat.com/docs/api-v1/customers)
and [TRANSFER event fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields).

## 7. Production deployment record (2026-09-13)

- Active release: `/root/chillnote-api/releases/subscription-security-20260913-01`.
  `current` was switched atomically; the prior release
  `mobile-20260912-pt-localization` remains available for rollback.
- Apple server API verified all 41 active legacy Apple accounts as valid yearly
  subscriptions. All 41 signed purchases were imported into RevenueCat and
  confirmed active there; no failed imports or missing Apple transactions.
  Apple credentials were used only locally against Apple's official API.
- Migration `20260913120000_revenuecat_transaction_owner` was applied. Subscription
  state was backed up to
  `/root/chillnote-api/backups/subscription-security-20260913-01/subscription-state.json`
  before reconciliation. All 85 selected existing Pro accounts still resolved
  to Pro after reconciliation.
- The release preserves the existing production sync implementation and other
  unrelated files. The 21 subscription regression tests passed under the
  production Node.js runtime before activation.
- An authenticated, temporary production test account submitted fabricated
  future, missing, and invalid expirations to `/subscription/verify`; every case
  remained `free`, and forged transaction fields were not persisted.
  `/invite/me` and `/invite/bind` returned 404. The temporary account and its
  RevenueCat customer were deleted after verification.
- Public `/health` returned `{"ok":true}`. No mobile binary or store release was
  part of this deployment. No new store purchases were initiated. Receipt imports
  did trigger RevenueCat ownership transfers; see the identity audit below.

## 8. UUID identity correction (2026-09-13, backend deployed; iOS pending)

The subsequent dashboard audit traced all 39 initially unmatched accounts to
existing anonymous customers with uppercase UUID aliases. The backend queried
lowercase UUIDs, which RevenueCat treats as separate identities. Importing the
receipts transferred ownership back to lowercase customers. These were not 39
missing purchases, and the lookup discrepancy does not prove dashboard revenue
or trial statistics were incomplete.

- iOS now canonicalizes UUIDs to lowercase at the RevenueCat login boundary;
  authentication, database IDs, bundle IDs and product IDs are unchanged.
- Backend webhook UUIDs are lowercased and deduplicated before database lookup.
- Sync first checks the canonical customer. If inactive, the same UUID's uppercase
  Apple entitlement is accepted for compatibility with old iOS builds. Opaque
  identifiers and anonymous IDs are not lowercased. Arbitrary aliases or client
  receipt metadata are never used to choose another customer.
- Both identity spellings write one canonical entitlement row under the existing
  transaction lock and transaction ownership constraint. Provider failures abort
  the sync instead of overwriting committed membership with a false negative.
- No receipt imports or mass transfers are needed to deploy this correction.
  Deploy backend compatibility first; ship the iOS normalization in an App Store
  update. Old clients can continue to use uppercase RevenueCat identities until
  updated. v1 fallback lookups can create empty uppercase customer profiles when
  no such customer exists; these profiles are not purchases or entitlement grants.
- Validate real-device login, purchase, restoration and transfer on controlled
  test accounts before declaring the entire billing lifecycle verified. Unit
  tests and a simulator build do not exercise Apple's production checkout.

Deployment: `current` now points to
`/root/chillnote-api/releases/subscription-identity-20260913-01`. The prior
`subscription-security-20260913-01` release remains available for rollback.
Only `dist/index.js`, `dist/revenueCat.js`, `dist/revenueCatSync.js` and subscription
test files were overlaid on the previous release; dependencies and sync code were
unchanged. All 30 subscription tests passed on production Node 20 before the
switch. Public health returned `{"ok":true}` after restart. No database migration,
receipt import, batch entitlement reconciliation or mobile release was performed.
