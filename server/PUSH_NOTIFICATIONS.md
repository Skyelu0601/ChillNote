# Push notification setup

The notification code is part of the app and backend, but APNs still needs an
Apple signing key and the database migration before production can send pushes.

## 1. Apple Developer configuration

1. Enable **Push Notifications** for the App ID
   `com.sponteoai.chillnote`.
2. Create an APNs authentication key (`.p8`) in Apple Developer.
3. Keep the key private. Never add it to Git.

## 2. Backend environment

Set these secrets in the production backend:

```text
APNS_KEY_ID=the_key_id_from_apple
APNS_TEAM_ID=your_apple_developer_team_id
APNS_BUNDLE_ID=com.sponteoai.chillnote
APNS_PRIVATE_KEY=the_full_p8_private_key
```

Optional tuning:

```text
FIRST_CREATION_REMINDER_DELAY_HOURS=24
NOTIFICATION_POLL_MS=60000
```

### Retired Weekly Post Ideas notifications

Weekly Post Ideas no longer runs a scheduled report worker or sends pushes.
The notification worker cancels queued `weekly_topics_ready` deliveries before
looking up devices. Import completion and first creation reminders remain active.
Historical reports and legacy mobile API routes are retained for compatibility.

For a production release that still supports `LEGACY_WEEKLY_TOPICS_ENABLED`, set
it to `false` in the shared runtime environment and restart the backend with the
updated environment to stop both generation and delivery immediately. The current
code removes the worker and push payload entirely, so that flag cannot re-enable
the retired notifications after deployment.

## 3. Database

Apply the Prisma migration:

```text
server/prisma/migrations/20260729120000_push_notification_reengagement/migration.sql
```

The new tables have RLS enabled and no public Data API policies. They are
intentionally backend-only.

## 4. Release check

Use a physical iPhone for the final test because the production path depends on
an APNs device token and the signed app environment.

1. Sign in and allow import-completion notifications.
2. Share a supported video to ChillScript while the main app is closed.
3. Confirm that only a successfully completed import sends a notification.
4. Tap it and confirm that the exact imported note opens.
5. Confirm that creating a draft suppresses the 24-hour reminder.
