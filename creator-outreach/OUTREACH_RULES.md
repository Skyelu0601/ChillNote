# ChillScript TikTok Creator Outreach Rules

This file is the durable source of truth for future TikTok creator campaigns.

## Goal and audience

Find creators whose audience may need frequent video transcription, idea extraction,
and original script creation. Current priority themes include creator education, UGC
workflows, faceless content, short-form video tips, content repurposing, video
scriptwriting, and AI tools for creators.

## Discovery rules

1. Use the Apify community Actor `scraper-mind/tiktok-email-scraper`.
2. Keep the raw JSON and CSV output for audit and recovery.
3. Normalize and deduplicate emails across keywords, runs, and historical leads.
4. Accept only complete TikTok URLs whose first path segment is `/@username`, including:
   - `https://www.tiktok.com/@username`
   - `https://www.tiktok.com/@username/video/...`
5. Reject:
   - `/discover/...`
   - `/tag/...`
   - `/search/...`
   - `/goto?...`
   - incomplete or non-TikTok URLs
   - malformed emails
6. Preserve the public source URL and search keyword on every lead.
7. Do not treat a search result as proof that the email belongs to the page author;
   direct `/@username` sources are the minimum structural requirement, not full identity proof.

## Identity and personalization

- Mass TikTok Email Scraper does not reliably return a creator's real name.
- Never guess a name from the email address, display title, or handle.
- Use `creator_name=there`, rendering as `Hi there,`, until a real name is verified.
- Generate the first line from the discovery keyword:
  - Faceless: `I found your TikTok while researching creators who make or teach faceless content.`
  - UGC: `I found your TikTok while researching creators who share UGC tips and workflows.`
  - Content creator: `I found your TikTok while researching creators who teach others how to make better content.`
  - Fallback: `I found your TikTok while researching creators who share content tips and workflows.`
- Do not claim to have watched a specific video unless that video was actually reviewed.
- Do not generate `specific_detail` from search snippets.

## Email validation and approval

- Reject invalid syntax immediately.
- MX validation proves only that the domain can receive mail; it does not prove that the
  individual mailbox exists.
- `valid` and `accepted` may be queued after approval.
- `mx_only` requires an explicit `--allow-mx-only` override.
- `invalid`, `risky`, and `unknown` are never sendable.
- New leads default to `approved=no` and `status=pending`.
- Paid discovery and live sending always require explicit confirmation.

## First email

Subject: `A creator tool you might like`

```text
Hi {{creator_name}},

{{personalization}}

I built ChillScript for creators who save TikToks, Reels, and YouTube videos for inspiration but want a calmer way to turn them into original content.

You can share a video directly to ChillScript, pull out the transcript and key ideas, then turn it into a fresh script in your own voice.

ChillScript has a Creator Affiliate Program that pays 30% commission on eligible subscriptions you refer. There’s no required posting schedule.

Interested in trying it? You can join here:

{{affiliate_signup_link}}

Once you’ve registered, reply “joined” and I’ll send you a complimentary year of ChillScript Pro so you can use the product yourself.

Best,
Skye Lu
Founder, ChillScript

If you’d rather not receive future emails from me, just reply “no” and I won’t contact you again.

ChillScript creator outreach
Rm 330, 3F, Bldg 2, 588 Zixing Rd, Minhang, Shanghai, China
```

Formatting rules:

- Send multipart email with HTML and plain-text alternatives.
- No images, buttons, attachments, or tracking pixels.
- The HTML version uses Times New Roman, with a plain-text fallback.
- The HTML footer uses a subtle divider, 12px type, and readable muted gray.
- The opt-out line and postal address remain visible and readable.
- First email has one conversion path: open the signup link, register, then reply `joined`.
- State 30% as applying to eligible subscriptions. Do not claim a commission basis or
  duration that has not been finalized in the program terms.
- Promise one complimentary year of Pro only as a verified Affiliate member benefit.

## Affiliate registration reply

The signup link is already present in the first email. Do not send a separate trial,
Partner invitation, or signup-link email.

When a creator replies that they registered, record the reply as `verification_pending`.
A reply is not proof of membership. Verify the member in the affiliate platform and
record their personal affiliate link before assigning a code.

## Partner code email

The second and final lifecycle email is sent only after all of the following are true:

1. The first email containing the affiliate signup link was sent.
2. The creator replied that registration was complete.
3. A human verified the membership in the affiliate platform.
4. The creator's personal affiliate link is recorded.
5. A unique `partner` offer code is assigned.

The code must come from the free-for-one-year Offer Code attached to the existing
auto-renewable product `com.chillnote.pro.yearly`, with `Don't auto-renew the subscription
at the end of this offer` enabled. It ends automatically and requires no cancellation.
Send the code and personal affiliate link in the existing email thread. Do not condition
the benefit on a positive review, App Store rating, or required posting schedule.

## Sending and lifecycle rules

- Default random delay: 60–120 seconds between messages.
- Record `sent_at` and SMTP `message_id` immediately after every successful send.
- Failed sends remain visible with the SMTP reason.
- Sent rows are never selected again.
- Sync IMAP for replies and bounces.
- A bounce changes the lead to invalid/bounced and blocks future sends.
- A sender-side `ESO_LOCAL_SPAM` rejection means the message never left Alibaba Mail;
  mark it `failed`, preserve the prior email validation status, and do not call the
  recipient mailbox invalid.
- Repeated sender-side spam blocks trigger a full campaign pause. Do not remove
  `data/SENDING_PAUSED` until the user explicitly approves a new provider or a tested
  sending strategy.
- When monitored sending is requested, poll IMAP between every message. A confirmed
  nonexistent recipient is marked invalid and skipped without stopping the queue. Stop
  immediately after any sender-side spam block or SMTP failure, save progress, and
  recreate `data/SENDING_PAUSED`.
- Old delivery notices that predate a newer retry must never overwrite the newer result
  or stop the active queue.
- A refusal or opt-out must set `approved=no` and block future marketing messages.
- Track sent, failed, bounced, replied, registration reported, membership verified,
  Partner code issued, and paid conversions. Do not rely on open rate as the primary metric.

## One-command campaign behavior

The keyword campaign command must perform these stages in order:

1. Preview Actor input and maximum advertised result fee.
2. With `--run`, start the paid Actor and save raw output.
3. Apply all source, syntax, and deduplication rules.
4. Validate new emails.
5. Save new leads as unapproved and generate text/HTML previews.
6. Without `--send`, stop safely.
7. With `--send`, show the exact eligible count and require `SEND N` confirmation.
8. Send only leads created by that campaign, using the approved first email.
