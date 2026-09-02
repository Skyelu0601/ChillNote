# Build a Creator Outreach System with AI

## A concise, no-coding guide for discovering relevant TikTok creators, reviewing contacts, and sending careful outreach

**Who this is for:** founders, marketers, agencies, creators, educators, service providers, and small businesses

**Experience required:** no coding experience

**Last updated:** August 2026
**Scope:** the local outreach workflow. A visual dashboard is not included.

---

## 1. What you are building

You will use an AI coding assistant as your technical teammate. You explain the campaign and make the decisions; the AI creates the local system, connects the services, checks data, prepares drafts, and records results.

The finished workflow should:

1. take one or more focused TikTok keywords;
2. ask before running a paid search;
3. find public creator business contacts through Apify;
4. accept only email sources that point directly to a TikTok `/@username` profile;
5. remove duplicates and permanently exclude opt-outs;
6. check email quality and prepare a reviewable draft;
7. require human approval before any real email is sent;
8. send slowly, record every result, and pause on serious delivery problems;
9. sync replies and bounces without automatically replying; and
10. help prepare the next step after a genuine positive reply.

This can support a product, service, course, store, sponsorship, app, or other legitimate offer. A free sample, discount, affiliate program, or reward is optional.

**Core rule:** AI may prepare and check the work, but a human approves spending, sending, and rewards.

## 2. What to prepare

You need:

- an AI coding assistant that can work in a local folder, such as Codex, Claude Code, or Cursor;
- an Apify account and access to Mass TikTok Email Scraper, or an equivalent Actor;
- a dedicated business mailbox on a domain you control;
- the secure sending and inbox-reading method supported by that mailbox provider;
- a real sender identity, postal address, and opt-out sentence; and
- optionally, ZeroBounce or another email-validation service.

The mailbox does not have to be Alibaba Mail. Gmail or Google Workspace, Microsoft 365 or Outlook, Zoho, Fastmail, and other business providers may work. Some use SMTP/IMAP and an app password; others prefer OAuth or an API. Ask the AI to check the provider's current official instructions instead of guessing.

Use public business contact information only when your offer is relevant. Follow the current rules of the platform, your email provider, and the countries involved. Keep opt-outs permanently suppressed, use truthful sender information and subject lines, and start with very small batches.

## 3. Give AI the complete brief

Open the AI assistant in an empty local folder and paste this prompt. Replace the bracketed parts, or ask the AI to interview you first.

```text
Build a local, review-first TikTok creator outreach system for my [business, product, service, or campaign]. I am not a developer, so explain decisions and errors in plain English.

Before building the email stage, ask me:
- what I am promoting and who it helps;
- which creators and audiences are relevant;
- what action I want an interested creator to take;
- whether I offer a sample, trial, discount, payment, affiliate commission, or no reward;
- my sender identity, postal address, and opt-out wording; and
- which business mailbox provider I use.

The workflow must:
- accept one or more TikTok content keywords;
- show the estimated Apify cost and wait for confirmation before a paid run;
- save the raw results for review;
- accept an email source only when it is a valid TikTok URL whose first path segment begins with /@username;
- reject Discover, Tag, Search, GoTo, malformed, incomplete, and non-TikTok sources;
- normalize emails and deduplicate them across all previous campaigns;
- validate syntax and domain mail records, with optional mailbox validation;
- keep a durable lead ledger and mark every new lead unapproved;
- prepare a profile summary and email preview for human review;
- allow only explicitly approved contacts into the sending queue;
- send in small batches with random gaps and save each result immediately;
- sync replies, invalid-address bounces, sender-side blocks, and opt-outs;
- skip only the affected contact for a confirmed nonexistent address;
- pause the campaign for a serious sender-side spam or policy block;
- never send an automatic reply;
- prepare, but never automatically send, the next step after a verified positive reply;
- prevent a unique coupon, gift, code, or reward from being assigned twice;
- keep tokens, passwords, contacts, message IDs, and reward codes out of Git and logs; and
- include tests for these safety rules.

Use the safest authentication method officially supported by my mailbox provider. Create a short RULES file so future AI sessions keep the same policies. Do not build a visual dashboard.

First show me the milestones, the accounts and values I need, and anything that may cost money. Do not contact external services yet.
```

Check the proposed plan before continuing. It should include discovery, direct-profile filtering, history-wide deduplication, validation, previews, human approval, monitored sending, reply syncing, opt-outs, and tests.

## 4. Connect accounts safely

Ask the AI:

```text
Create a local secrets template and make sure the completed secrets file is ignored by Git. Include fields for Apify, my mailbox provider's supported authentication method, and optional email validation. Do not print secret values or ask me to paste them into chat. Open the local file and explain which values I should enter myself.
```

Find the Apify personal API token in Apify Console under **Settings → API & Integrations** (wording may change). API documentation such as “List webhooks” is not the token.

For email, tell the AI your provider's name and ask it to use current official setup instructions. Do not use your normal webmail password unless the provider explicitly requires it. If a token or password is exposed in chat, a screenshot, or a public repository, revoke it and create a new one.

After entering the values, request a connection-only test:

```text
Test Apify access, email sending access, and inbox-reading access without running a paid scrape and without sending an email. Do not display secrets. Report each connection as ready or not ready and explain any failure in plain English.
```

## 5. Build and test discovery

Start with a narrow keyword that describes content your ideal creator already publishes, for example `UGC creator tips` rather than `marketing`. Ask for a tiny test run first.

The system must accept a source only when the URL belongs to TikTok and its first path segment begins with `/@username`, such as:

```text
https://www.tiktok.com/@examplecreator
```

Reject `/discover/`, `/tag/`, `/search/`, GoTo links, unrelated websites, and profile names inferred only from an email address. This rule keeps every contact traceable to a real creator profile.

Before paying for a larger run, ask the AI to show:

- the keyword and requested result count;
- the estimated cost;
- accepted and rejected counts with reasons;
- duplicates found in campaign history;
- each creator's direct profile source; and
- email status: valid, risky, invalid, or unknown.

Unknown or risky does not mean approved. Keep every new contact unapproved until you inspect the profile, relevance, address, and email draft.

## 6. Create the email and review queue

Keep the first message short, honest, and easy to answer. Personalization should come only from information actually reviewed; never invent a video detail.

```text
Subject: A creator tool you might like

Hi [Name],

I came across your content about [specific reviewed topic]. I am working on [one-sentence description of the offer and who it helps].

I thought it might be useful for your content workflow. If you are interested, I would be happy to [offer the next step: share access, send a sample, explain the collaboration, or arrange a quick call]. No obligation to post.

Would you like me to send the details?

Best,
[Sender name]
[Business name]
[Postal address]
[Simple opt-out sentence]
```

Ask the AI to generate a review table showing the creator, profile URL, follower count when available, email and validation result, why the creator matches, personalization evidence, subject, body, and approval status.

Approve only contacts where:

- the profile opens at a direct `/@username` URL;
- the creator and audience fit the offer;
- the email appears to be a public business contact;
- the personalization is specific and true;
- the message states the offer accurately; and
- the contact is not duplicated, bounced, or opted out.

## 7. Test, approve, and send carefully

First send the complete email to your own outside test address. Check the sender name, reply-to address, formatting, links, footer, inbox placement, and whether the reply is detected. Then run a dry run that creates the exact queue without sending.

Use exact approval language so a casual “okay” cannot launch a campaign:

```text
Show me the final approved queue and do not send yet.
```

```text
SEND 10
```

Begin with a very small batch. The system should save the outcome after every message and check the mailbox between batches. A confirmed nonexistent recipient should be marked invalid and skipped. A provider spam/policy rejection, authentication failure, or unusual cluster of bounces should pause the campaign for review. Do not rewrite messages merely to evade filters; improve relevance, list quality, authentication, accuracy, and sending pace.

Every record should end with a clear status such as pending, approved, sent, replied, bounced, opted out, or suppressed.

## 8. Handle replies and optional next steps

The system may classify replies and prepare drafts, but it should never reply automatically. Review the original conversation before responding.

If the campaign is specifically recruiting Affiliate partners, state the commission, signup link, and member benefit in the first email. Keep the path short: signup first, then one follow-up in the same thread after registration is verified.

If you offer a unique code, sample, or gift, store its status as available, assigned, sent, or redeemed when that information is available. Do not reuse it. For ChillScript Affiliate members, use only the approved free-for-one-year Offer Code attached to `com.chillnote.pro.yearly`, with auto-renew disabled. Confirm the commission and invitation method before promising either.

## 9. Final acceptance checklist

Do not use the system for a real campaign until all of these are true:

- Apify and mailbox connection-only tests pass without exposing secrets.
- A paid scrape always requires confirmation.
- Only direct TikTok `/@username` sources are accepted; Discover, Tag, Search, GoTo, malformed, and non-TikTok sources are rejected.
- Deduplication checks the entire history, and opt-outs remain permanently suppressed.
- Every email has a validation status, and every new contact starts unapproved.
- Email previews show the full subject, body, source, and personalization evidence.
- Only explicitly approved contacts can be queued.
- A self-test and dry run succeed before real sending, and exact `SEND N` approval is required.
- Each send, reply, bounce, and opt-out is recorded; serious sender-side failures pause the campaign.
- No creator reply is sent automatically.
- Unique rewards cannot be assigned twice.
- Secrets, contact lists, and reward data are excluded when the project is shared.

Once these checks pass, future use can be simple: give the AI a keyword and target count, review the estimate, inspect the accepted creators, approve the drafts, run a dry run, and authorize a small batch.

## Official references

Before a real campaign, review the latest [Apify documentation](https://docs.apify.com/), [TikTok Terms of Service](https://www.tiktok.com/legal/terms-of-service), your email provider's official sending documentation, and the commercial-email rules that apply to you and your recipients. ChillScript partner access uses an Apple subscription Offer Code with auto-renew disabled; follow [Apple's subscription Offer Code guide](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/).
