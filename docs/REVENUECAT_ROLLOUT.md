# RevenueCat rollout runbook

This rollout keeps the existing Apple and Google verification paths as safety
fallbacks while RevenueCat becomes the shared source for offerings, purchases,
restore, customer state, analytics, and subscription lifecycle events.

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
verifications must be zero. Keep the legacy Apple subscription columns and
verification endpoint in production for at least one complete renewal cycle.

As a second safety net, the iOS app calls `syncPurchases` once only when the old
backend says the signed-in user is Pro but RevenueCat does not yet know the
entitlement. It never removes Pro access merely because CustomerInfo is missing,
inactive, delayed, or temporarily unavailable.

## 5. Release verification

Use App Store sandbox/TestFlight and a Google Play internal-testing build to
verify weekly and yearly purchase, restore, renewal, cancellation, expiration,
pending Google payment, app reinstall, and switching between two accounts.

For each scenario confirm all three views agree:

- the app's Pro state;
- `GET /subscription/status` on the backend;
- the customer and `pro` entitlement in RevenueCat.

Release gradually. During the migration window, alert on webhook 401/403/503
responses, failed RevenueCat customer lookups, and any case where the legacy
backend says Pro while RevenueCat says inactive. Do not remove the legacy
fallback until existing iOS subscribers have renewed or expired and the mismatch
count has remained at zero.
