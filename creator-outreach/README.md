# ChillScript Creator Outreach

A small, review-first outreach tool for ChillScript creator partnerships.

The creator lifecycle uses exactly two emails:

1. The first email introduces the 30% Affiliate Program, includes the signup link, and
   promises one complimentary year of Pro after verified registration.
2. After the creator replies that they registered, a human verifies the membership and
   personal referral link; the second email sends the one-year code.

The durable campaign policy, approved copy, source filters, and lifecycle rules live in
[`OUTREACH_RULES.md`](OUTREACH_RULES.md). Read it before changing campaign behavior.

## Start from a keyword

Preview a complete keyword campaign without spending money or sending email:

```bash
npm run campaign:tiktok -- \
  --keyword "video script tips" \
  --max-emails 20
```

Run paid discovery, apply all permanent filters, validate new emails, import them as
unapproved, and generate text/HTML previews:

```bash
npm run campaign:tiktok -- \
  --keyword "video script tips" \
  --max-emails 20 \
  --run
```

To offer live sending in the same command, add `--send`. When ZeroBounce is not
configured, add `--allow-mx-only` only after deliberately accepting domain-only
validation. The command still stops for an exact `SEND N` confirmation:

```bash
npm run campaign:tiktok -- \
  --keyword "video script tips" \
  --max-emails 20 \
  --run \
  --send \
  --allow-mx-only
```

This command saves raw Actor output, accepts only direct `/@username` TikTok sources,
deduplicates against all historical leads, never guesses creator names, creates the
approved category opener, validates addresses, writes previews, and sends only the new
leads from that campaign. Live keyword campaigns are capped at 105 requested results.

## Safety model

- The default command never sends email.
- A lead must have `status=pending`, `approved=yes`, and a verified email status.
- A live batch is capped at 10 messages.
- Live sending requires typing an exact confirmation phrase.
- Sent rows are never selected again.
- Credentials stay in the workspace root `.env.local`, which is ignored by Git.
- IMAP sync reads replies and bounces but never sends an automatic reply.
- The one-year Partner code inventory is ignored by Git.
- A one-year code cannot be assigned before affiliate membership is recorded.

## Two-email Affiliate workflow

Place the App Store Connect one-time-use code exports here:

```text
data/offer-codes/partner.csv
data/offer-codes/partner.csv.product-id
```

Both files are ignored by Git. The code export must come from the approved free-for-one-year
Offer Code attached to the existing Yearly subscription:

- Product: `com.chillnote.pro.yearly`
- Offer type: Free for the first year
- Auto-renew: `Don't auto-renew the subscription at the end of this offer`

The resulting one-year access ends automatically and requires no cancellation.

The `.product-id` marker contains exactly `com.chillnote.pro.yearly`. Assignment fails
closed when the marker is missing or mismatched.

The first email already contains the Affiliate signup link. After the creator replies that
registration is complete, verify the membership in the Affiliate platform and record their
personal link. Only then assign and send the one-year code:

```bash
npm run mark:partner-joined -- --email creator@example.com --affiliate-link "https://example.com/personal-link" --confirm "MARK PARTNER JOINED creator@example.com"
npm run assign:offer-code -- --email creator@example.com --name "Creator Name"
npm run send:partner-code -- --email creator@example.com --confirm "SEND PARTNER CODE creator@example.com"
```

## Setup

Requirements:

- Node.js 20+
- Alibaba Mail third-party client access enabled
- IMAP and SMTP enabled for `hello@skyeluai.com`
- A revocable third-party client security password in `../.env.local`

Install:

```bash
cd creator-outreach
npm install
```

Test authentication without sending or reading messages:

```bash
npm run test:connection
```

The defaults follow Alibaba Mail's official SSL configuration:
SMTP `smtp.qiye.aliyun.com:465` and IMAP `imap.qiye.aliyun.com:993`.
See [Alibaba Mail server addresses and ports](https://help.aliyun.com/en/document_detail/36576.html).

## Lead workflow

The source of truth is `data/leads.csv`.

Important columns:

- `email_source`: public page where the business email was found
- `source_keyword`: TikTok search keyword(s) used to discover the email
- `email_status`: `unchecked`, `mx_only`, `valid`, `accepted`, `invalid`, or `risky`
- `approved`: only `yes` is sendable
- `status`: `pending`, `sent`, `failed`, `bounced`, or `blocked`
- `message_id`: captured after SMTP sending and used to match replies

The existing ten-person campaign is recorded as history and cannot be resent.

## Discover TikTok creator emails with Apify

This project can call the community Actor `scraper-mind/tiktok-email-scraper` through
the official Apify client. Add the token from Apify Console to `../.env.local`:

```dotenv
APIFY_TOKEN=your_local_apify_token
```

Preview a request without starting the paid Actor:

```bash
npm run discover:tiktok-emails -- \
  --keyword "AI productivity" \
  --keyword "note taking tips" \
  --location "United States" \
  --max-emails 20
```

After reviewing the printed request and estimated maximum result fee, add `--run`:

```bash
npm run discover:tiktok-emails -- \
  --keyword "AI productivity" \
  --keyword "note taking tips" \
  --location "United States" \
  --max-emails 20 \
  --run
```

Use repeated `--domain` flags to override the default Gmail, Outlook, Hotmail, Yahoo,
and iCloud domains. Results are deduplicated by email and written to local JSON and
CSV files under `data/tiktok-email-runs/`. They are never automatically added to the
send queue; review and validate them before copying selected leads into `data/leads.csv`.

Import all locally saved TikTok email runs into the review queue:

```bash
npm run import:tiktok-emails
npm run import:tiktok-emails -- --write
```

The first command is a dry run. The second merges duplicate emails, preserves existing
lead history, creates a category-specific opening line, and adds new rows with
`approved=no`, `status=pending`, and `email_status=unchecked`. Because scraper results
do not reliably include a creator's real name, imported rows use `Hi there,` until a
name is manually confirmed. Only direct TikTok profile or video paths beginning with
`/@username` are accepted; Discover pages, Tag pages, incomplete URLs, and malformed
email addresses are excluded. No email is sent by either command.

### 1. Add a lead

Copy the shape from `data/leads.example.csv` into `data/leads.csv`. Use a unique `id`,
set `email_status=unchecked`, `approved=no`, and `status=pending`.

### 2. Check email

```bash
npm run check:emails
```

Checks are limited to pending leads by default, including with `--all`; sent and bounced
history is only rechecked when `--include-history` is explicitly supplied.

Without `ZEROBOUNCE_API_KEY`, this performs syntax and MX checks only and assigns
`mx_only`. That catches missing domains/MX records but does not prove the mailbox exists.

To require ZeroBounce validation, add its API key locally to `../.env.local`:

```dotenv
ZEROBOUNCE_API_KEY=your_local_key
```

Never commit or paste this key into chat.

### 3. Review and approve

Edit the row only after checking the TikTok profile, public email source, activity,
content fit, and rendered copy:

```csv
approved=yes
```

Preview approved pending emails:

```bash
npm run preview
```

Write copyable preview files:

```bash
npm run preview -- --write
```

### 4. Dry-run the send queue

```bash
npm run send
```

This prints the queue and sends nothing.

### 5. Send

```bash
npm run send -- --send
```

The command asks for an exact phrase such as `SEND 3`. Messages are spaced by a
random 60–120 seconds. Change the range only when needed:

```bash
npm run send -- --send --delay-min 90 --delay-max 180
```

`mx_only` addresses are refused by default. A deliberate override is available:

```bash
npm run send -- --send --allow-mx-only
```

Use the override sparingly because an MX record does not prove mailbox deliverability.

Bulk TikTok approval requires an exact count confirmation. Live batches remain capped
at 10 unless the explicit `--bulk-confirmed` flag is present; that override is capped
at 105 and still requires the normal live-send confirmation phrase.

### 6. Sync replies and bounces

```bash
npm run sync
```

On the first run it checks the last 14 days. To choose a different initial window:

```bash
npm run sync -- --days 30
```

The sync state is local and ignored by Git.

## Tests

```bash
npm test
```

The tests cover eligibility, template rendering, address normalization, reply matching,
and Alibaba Mail bounce parsing.
