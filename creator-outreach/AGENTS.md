# Creator Outreach Project Instructions

Before changing or running this project, read `OUTREACH_RULES.md` completely.

- Treat `data/leads.csv` as the source of truth. Preserve sent, bounced, blocked, and reply history.
- Never expose `.env.local` values, Apify tokens, mailbox passwords, or validation API keys.
- Only import TikTok sources whose first path segment is `/@username`. Reject Discover,
  Tag, search, redirect, incomplete, and non-TikTok URLs.
- Deduplicate by normalized email across the current run and all historical leads.
- Do not infer a creator's real name from an email or handle. Use `Hi there,` until verified.
- Keep the approved first-email subject, copy, opt-out notice, postal address, HTML footer,
  and plain-text fallback unless the user explicitly changes them.
- The first email must introduce the Affiliate Program, state the 30% commission on
  eligible subscriptions, include the approved signup link, and explain that verified
  members receive one complimentary year of Pro.
- Do not send a trial code, delayed Partner invitation, or separate affiliate-signup email.
- Never assign or send a one-year `partner` code until the creator reports completing
  signup, a human verifies their membership, and their personal affiliate link is recorded.
- Partner codes must come only from the approved free-for-one-year Offer Code attached to
  `com.chillnote.pro.yearly`, with auto-renew disabled. Never use the weekly or monthly
  products or any non-renewing Creator Pass product.
- Paid Apify runs and live email sends require explicit flags and an exact confirmation.
- Invalid, risky, or unknown emails are never sendable. `mx_only` requires an explicit override.
- Never send the same lead twice. Write send results and message IDs immediately.
- Do not run two lead-writing or sending processes concurrently.
