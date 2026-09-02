# Google Play Billing setup

## Products

Create these subscription products in Play Console. The IDs must match the Android and iOS clients:

- `com.chillnote.pro.weekly`
- `com.chillnote.pro.yearly`

`com.chillnote.pro.monthly` is retired from sale but remains recognized by the
clients and backend so existing subscribers can renew and restore access.

Each product needs an active base plan. Prices and trial offers are configured in Play Console and are displayed from `ProductDetails`; prices are never hard-coded in the app.

## RevenueCat rollout

The Android rollout is deliberately split into two safe stages. The existing
backend remains the source of truth for access in both stages, so introducing
RevenueCat does not change product IDs or invalidate an existing subscription.

### Stage 1: make Google Play revenue visible

1. In the existing RevenueCat project, add a Google Play app with package name
   `com.sponteoai.chillscript`.
2. Reuse the Google Play service-account JSON already used for releases and
   backend verification. In Play Console, its app permissions must include:
   `View app information`, `View financial data`, `Manage orders and
   subscriptions`, and `Manage store presence`.
3. Connect the credentials in RevenueCat, copy RevenueCat's Pub/Sub topic to
   Play Console's Monetization setup page, then send a test notification.
4. Enable RevenueCat's tracking of new purchases before the SDK release. Choose
   anonymous App User IDs for these server-notification-only purchases; once the
   SDK is installed, signed-in users are identified with their existing backend
   user ID.

There are currently no historical Google Play subscriptions to migrate. Google
credential validation can take up to 24–36 hours after permissions are changed.

### Stage 2: switch the app to the RevenueCat SDK

1. Import the weekly and yearly products into RevenueCat. Keep the retired
   monthly product recognized for historical subscribers, but do not add it to
   the current offering.
2. Create the `pro` entitlement and attach all three recognized products.
3. Create a current offering containing the weekly and yearly packages.
4. Put the Android public SDK key in either CI as
   `CHILLSCRIPT_REVENUECAT_ANDROID_API_KEY`, or locally in the ignored
   `android/local.properties` file:

   ```properties
   chillscript.revenuecat.androidApiKey=goog_...
   ```

With a valid key the app uses RevenueCat for customer identity, offerings,
purchases, restore, and one-time migration of pre-SDK purchases. If the key is
missing, the current direct Google Billing path remains active so a dashboard or
release configuration mistake cannot remove checkout from production.

## Backend verification

1. Create a Google Cloud service account.
2. Enable Google Play Android Developer API for the linked Cloud project.
3. Invite the service account in Play Console.
4. Grant subscription/order access.
5. Configure the three `GOOGLE_PLAY_*` environment variables documented in `server/README.md`.
6. Deploy the backend.

The app sends `productId` and `purchaseToken` to `/subscription/google/verify`. The backend verifies the token using `purchases.subscriptionsv2.get`, checks account binding and expiration, stores the entitlement, and acknowledges a new purchase.

## Testing

- Upload a signed AAB to an internal testing track; Play Billing does not provide complete product behavior for a sideloaded debug APK.
- Add license tester accounts in Play Console.
- Before the SDK release, verify the Pub/Sub test event and confirm imported
  Google transactions appear in RevenueCat charts.
- Test weekly, yearly, cancellation, pending payment, restore, expiration,
  account switching, and a customer upgrading from a pre-SDK build.
