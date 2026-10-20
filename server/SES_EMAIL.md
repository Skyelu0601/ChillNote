# Amazon SES email delivery

ChillScript uses Amazon SES only as the delivery provider. Scheduling,
deduplication, subscription checks, consent, and suppression state remain in
the ChillScript database.

The first enabled lifecycle is a service reminder for an active RevenueCat
trial. RevenueCat `INITIAL_PURCHASE` events with `period_type=TRIAL` schedule
one message 48 hours before `expiration_at_ms`. Cancellation, renewal,
expiration, and transfer events cancel pending reminders. The worker checks the
current RevenueCat entitlement again immediately before sending.

## Billing-day renewal checks

When email delivery and the RevenueCat API key are configured, the email worker
also scans mobile entitlements every five minutes. It saves checks for billing
dates within the next 24 hours (and catches up only for dates within the past
24 hours). A check becomes due one hour after the saved billing timestamp;
the existing email worker polls every 60 seconds by default. Timing follows the
store's renewal instant, not a midnight-based calendar schedule.

Each check fetches fresh RevenueCat customer information. A new purchase period
with a later expiry cancels the reminder and schedules the next check. An expiry
extension alone is not treated as payment success: Google Play can extend access
during silent grace or an explicit grace period. If payment has not been
confirmed after one hour, the check sends the billing-issue recovery template,
even when the store has not yet reported an explicit billing issue. The template
does not claim that the store reported the issue. The account owner authorized
this billing-issue treatment for unconfirmed renewals on October 7, 2026.

Voluntary cancellation, refunds, paused subscriptions, family sharing, sandbox
subscriptions and non-mobile stores are excluded at send time. Missing ownership
or a changed subscription cancels a check; a failed API request is retried, not
treated as proof of payment failure. Checks older than 24 hours are cancelled.
Subscription/billing email opt-outs, confirmed-email requirements and service
suppression apply to these emails. These checks do not grant or revoke Pro.
Checks queued under the previous five-minute delay are deferred until one hour
has elapsed. Confirmed billing-issue webhooks continue to send immediately.

Checks share the existing billing-recovery deduplication key with billing-issue
webhooks using the original billing date rather than the grace deadline. Delayed
webhooks additionally check for sent recovery reminders near their event date,
and replace pending checks in that window. Renewal and transfer webhooks cancel
pending checks. No database migration or client update is required.

References: [Google Play silent grace period](https://developer.android.com/google/play/billing/lifecycle/subscriptions#silent-grace-period)
and [RevenueCat customer schema](https://www.revenuecat.com/docs/api-v1/customer-info-model).

The account owner confirmed Marketing is on by default for registered users.
Only an explicit unsubscribe turns it off. The preference API and signed
unsubscribe endpoint preserve that choice; the win-back scheduler sends
automatically when enabled.

## Reuse the existing SES setup

The existing AWS setup was verified on September 21, 2026. Reuse it rather than
creating another SES identity:

- Region: `us-east-1` (US East, N. Virginia)
- Domain identity: `chillnoteai.com` — verified
- Easy DKIM: successful, enabled, RSA 2048-bit
- Custom MAIL FROM: `bounce.chillnoteai.com`
- Production quota: 50,000 messages per 24 hours, 14 messages per second
- Account suppression: enabled for bounces and complaints
- Configuration sets: none; leave `SES_CONFIGURATION_SET` empty initially

If these values ever change, inspect the AWS SES console before creating
anything new:

1. **Verified identities**: reuse the existing `chillnoteai.com` identity or
   verified sender address if it is healthy.
2. **Account details**: confirm the account has production access and note its
   region. Sandbox accounts can send only to verified recipients.
3. **DKIM**: preserve existing CNAME records. Do not replace working selectors.
4. **Suppression list**: enable account-level suppression for both bounces and
   complaints.
5. **Apple private relay**: register the exact From domain in Apple Developer
   “Sign in with Apple for Email Communication.”

The public domain also has a DMARC record. SES identity, DKIM, MAIL FROM,
production access, and account-level suppression are already ready in
`us-east-1`.

## Runtime configuration

```text
EMAIL_ENABLED=false
SES_REGION=us-east-1
SES_FROM_EMAIL=ChillScript <notifications@chillnoteai.com>
SES_REPLY_TO_EMAIL=support@chillnoteai.com
SES_CONFIGURATION_SET=
SES_EVENT_TOPIC_ARN=
EMAIL_UNSUBSCRIBE_SECRET=generate-a-long-random-secret
EMAIL_POLL_MS=60000
SES_MARKETING_FROM_EMAIL=ChillScript <hello@chillnoteai.com>
EMAIL_PUBLIC_BASE_URL=https://api.chillnoteai.com
EMAIL_MARKETING_SCAN_MS=21600000
EMAIL_MARKETING_DAILY_LIMIT=50000
EMAIL_MARKETING_HOLDOUT_PERCENT=10
EMAIL_MARKETING_ENABLED=false
EMAIL_MARKETING_POSTAL_ADDRESS=Your public business mailing address
```

Keep `EMAIL_ENABLED=false` until the migration is applied, SES production
access is confirmed, and a verified sender is configured.

The AWS SDK uses the standard credential provider chain. The current production
server is not on AWS and has no AWS credential file or email environment
variables, so configure
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as deployment secrets. Never
commit them.

The runtime identity needs only `ses:SendEmail` for the verified identity. A
minimal starting policy is:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "ses:SendEmail",
    "Resource": "arn:aws:ses:REGION:ACCOUNT_ID:identity/chillnoteai.com"
  }]
}
```

## Deployment checklist

1. Apply Prisma migrations and regenerate Prisma Client.
2. Deploy with `EMAIL_ENABLED=false` and confirm normal server health.
3. Send an SES console test to an internal address.
4. Confirm SPF/DKIM/DMARC and Apple private relay delivery.
5. Configure the SES identity, region, and credentials in deployment secrets.
6. Enable `EMAIL_ENABLED=true`.
7. Start with internal or sandbox RevenueCat accounts and confirm that each
   dedupe key produces at most one sent delivery.
8. Monitor SES reputation, bounces, complaints, and the account suppression
   list before increasing volume.

## Preference endpoints

- `GET /email/preferences` returns the signed-in user's marketing preference.
- `PUT /email/preferences` accepts `{ "marketingSubscribed": true|false }`.
- `GET /email/unsubscribe?token=...` renders a confirmation page.
- `POST /email/unsubscribe?token=...` records a marketing opt-out.

The signed email-choices page has two categories: Marketing covers the
win-back sequence and the follow-up after cancelling a trial; Subscription
and billing covers trial-ending and payment-issue reminders. It never
re-enables an email category from an unauthenticated email link. Existing
List-Unsubscribe one-click POSTs turn off Marketing only. Account and security messages are not part of
this email automation. Opting out of reminders does not cancel a store
subscription or change payment retries.

## Marketing win-back sequence

The marketing scheduler considers a user inactive only after their most recent
note, link import, or Chillo conversation has been unchanged for seven days.
It then sends at most three messages: after 7 days of inactivity, 7 days after
the first message, and 16 days after the second message. Any new meaningful
activity cancels pending messages from the old inactivity cycle.

All users are eligible by default unless they explicitly unsubscribe from Marketing. Active billing
issues, service suppression, unsubscribe state, and a service email sent in the
previous 72 hours all block or postpone marketing delivery. The default daily
limit matches the current SES quota of 50,000 messages per rolling 24 hours,
and a stable 10% holdout group receives no win-back
email so reactivation lift can be measured against a control.

Keep `EMAIL_MARKETING_ENABLED=false` until the public business mailing address
is configured and verified in a test email. The marketing scheduler requires
both `EMAIL_MARKETING_ENABLED=true` and a non-empty
`EMAIL_MARKETING_POSTAL_ADDRESS`; lifecycle service email remains independent.

Marketing messages use RFC 8058 one-click unsubscribe headers and the signed
public unsubscribe endpoint. The existing-user consent backfill preserves
explicit opt-outs and records `owner_confirmed_existing_users_2026_09_21` as
the consent source.

## SES delivery event tracking

Set `SES_CONFIGURATION_SET` on every tracked send and point its SES event
destination at the SNS topic in `SES_EVENT_TOPIC_ARN`. Subscribe
`https://api.chillnoteai.com/webhooks/ses` to that topic. The endpoint verifies
the SNS signature, exact topic ARN, regional certificate URL, and subscription
URL before accepting or confirming a message.

Track Send, Delivery, DeliveryDelay, Bounce, Complaint, and Reject events. They
are stored in the backend-only `EmailEvent` table and summarized on the related
`EmailDelivery`. Permanent bounces and complaints suppress future sending for
that account; transient bounces remain visible without permanently suppressing
the address. Do not enable Open or Click events unless the privacy policy and
product requirements explicitly call for engagement tracking.

### 营销邮件回到 App

三封营销邮件统一使用 `${EMAIL_PUBLIC_BASE_URL}/email/open-app`，不再使用旧的 `EMAIL_MARKETING_CTA_URL` 覆盖配置或官网首页。该公开入口只负责唤起手机 App，不读取用户资料、不更改订阅。

- iOS：沿用已注册的 `chillnote://open`，打开 App，不触发录音。
- Android：使用限定包名的 Intent 打开 `chillnote://open`，需要包含 `open` intent filter 的客户端版本；旧版本未匹配时进入 Google Play 更新。
- 邮件浏览器可能阻止自动唤起，页面保留手动「Open ChillScript」按钮；未安装时可用商店入口，电脑上提示用手机打开。
- 上线顺序：先发布含 Android 新入口的版本，再部署后端。需在手机上的 Apple Mail / Gmail 中验证已安装、未安装和旧 Android 版本场景；本地预览不证明真机邮件跳转成功。
