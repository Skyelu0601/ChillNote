# Google Play Billing setup

## Products

Create these subscription products in Play Console. The IDs must match the Android and iOS clients:

- `com.chillnote.pro.monthly`
- `com.chillnote.pro.yearly`

Each product needs an active base plan. Prices and trial offers are configured in Play Console and are displayed from `ProductDetails`; prices are never hard-coded in the app.

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
- Test monthly, yearly, cancellation, pending payment, restore, expiration and account switching.
