# App Store Review Login (ChillNote)

## Reviewer Login Credentials

- Login method: Email + verification code
- Whitelist email: `appreview@chillnoteai.com`
- Verification code: `202602`

## Reviewer Steps

1. Open the app and tap `Continue with Email`.
2. Enter whitelist email: `appreview@chillnoteai.com`.
3. Tap `Send Verification Code` (for reviewer account, no real email is required).
4. Enter verification code: `202602`.
5. Tap `Verify & Login`.

## Developer Notes

- Credentials are configured in `chillnote/Info.plist`.
- Config keys:
  - `APP_REVIEW_LOGIN_ENABLED`
  - `APP_REVIEW_WHITELIST_EMAILS`
  - `APP_REVIEW_VERIFICATION_CODE`
- Multiple whitelist emails are supported by comma separation.
- After review is complete, set `APP_REVIEW_LOGIN_ENABLED` to `false`.

## App Review Privacy Notes

Use the following points in App Store Connect review notes for builds that include AI features:

- On first use of any AI feature, the app shows an in-app consent sheet before data is sent for AI processing.
- Voice notes and text intentionally submitted to AI are sent to ChillNote's secure server and then to Google Gemini via Google Cloud only to complete the user's request.
- Raw audio is processed ephemerally and is not retained on our servers after processing.
- ChillNote and its third-party AI partners do not use user notes or recordings to train models.
