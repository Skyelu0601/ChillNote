import test from "node:test";
import assert from "node:assert/strict";
import { isValidEmailSyntax } from "../src/email-validation.mjs";
import { shouldStopAfterDeliveryEvent } from "../src/delivery-policy.mjs";
import {
  assignNextOfferCode,
  parseAppleOfferCodes,
} from "../src/offer-codes.mjs";
import {
  selectSendableLeads,
  normalizeEmail,
} from "../src/lead-store.mjs";
import { renderTemplate } from "../src/template.mjs";
import {
  classifyIncomingMessage,
  isStaleDeliveryNotice,
} from "../src/inbox.mjs";
import {
  buildTikTokEmailInput,
  deduplicateTikTokEmailResults,
  parseTikTokEmailArgs,
} from "../src/tiktok-email.mjs";
import {
  buildTikTokLeadRows,
  handleFromTikTokUrl,
  isTraceableTikTokSource,
  personalizationForKeywords,
} from "../src/tiktok-lead-import.mjs";
import {
  isCampaignSendable,
  parseTikTokCampaignArgs,
} from "../src/tiktok-campaign.mjs";
import {
  isDirectTikTokSource as isDashboardTikTokSource,
  parseKeywords,
  summarizeLeads,
} from "../src/dashboard.mjs";
import {
  applyReplyIntent,
  classifyReplyIntent,
} from "../src/lifecycle.mjs";

test("normalizes email addresses", () => {
  assert.equal(normalizeEmail("  Person@Example.COM "), "person@example.com");
});

test("validates basic email syntax", () => {
  assert.equal(isValidEmailSyntax("person@example.com"), true);
  assert.equal(isValidEmailSyntax("not-an-email"), false);
  assert.equal(isValidEmailSyntax(".creator@gmail.com"), false);
  assert.equal(isValidEmailSyntax("creator..tips@gmail.com"), false);
});

test("selects only approved, pending and verified leads", () => {
  const rows = [
    { id: "a", status: "pending", approved: "yes", email_status: "valid" },
    { id: "b", status: "pending", approved: "no", email_status: "valid" },
    { id: "c", status: "sent", approved: "yes", email_status: "accepted" },
    { id: "d", status: "pending", approved: "yes", email_status: "mx_only" },
  ];
  assert.deepEqual(selectSendableLeads(rows).map((row) => row.id), ["a"]);
  assert.deepEqual(
    selectSendableLeads(rows, { allowMxOnly: true }).map((row) => row.id),
    ["a", "d"],
  );
});

test("renders a personalized template", () => {
  const result = renderTemplate(
    "Hi {{creator_name}}. I {{personalization}}. {{audience_fit}}",
    {
      id: "creator",
      creator_name: "Alex",
      personalization: "liked your creator growth experiments",
      audience_fit: "This fits your audience.",
    },
  );
  assert.equal(
    result,
    "Hi Alex. I liked your creator growth experiments. This fits your audience.",
  );
});

test("classifies Alibaba Mail MX bounces against a known lead", () => {
  const result = classifyIncomingMessage(
    {
      subject: "来自no-reply@mailsupport.aliyun.com的退信",
      text: "退信通知 收信地址 management@lastshotmedia.co 退信原因 域名不存在或没有添加邮件解析（MX）记录",
      from: { value: [{ address: "no-reply@mailsupport.aliyun.com" }] },
    },
    [{ id: "aayush", email: "management@lastshotmedia.co" }],
  );
  assert.deepEqual(result, {
    type: "bounce",
    leadId: "aayush",
    reason: "recipient domain has no MX record",
  });
});

test("classifies direct replies by sender address", () => {
  const result = classifyIncomingMessage(
    {
      subject: "Re: ChillScript creator partnership",
      text: "Sounds interesting.",
      from: { value: [{ address: "creator@example.com" }] },
    },
    [{ id: "creator", email: "creator@example.com", message_id: "" }],
  );
  assert.equal(result.type, "reply");
  assert.equal(result.leadId, "creator");
});

test("matches bounce recipients by exact email instead of substrings", () => {
  const result = classifyIncomingMessage(
    {
      subject: "来自no-reply@mailsupport.aliyun.com的退信",
      text: "Final recipient: kaytelynn.ugc@gmail.com\nESO_LOCAL_SPAM: spamed by local spam engine",
      from: { value: [{ address: "no-reply@mailsupport.aliyun.com" }] },
    },
    [
      { id: "short", email: "ugc@gmail.com" },
      { id: "exact", email: "kaytelynn.ugc@gmail.com" },
    ],
  );
  assert.deepEqual(result, {
    type: "outbound_blocked",
    leadId: "exact",
    reason: "Alibaba outbound spam filter blocked the message before delivery",
  });
});

test("does not apply an old bounce to a newer retry", () => {
  assert.equal(
    isStaleDeliveryNotice("2026-08-08T06:30:14.000Z", "2026-08-08T07:13:40.854Z"),
    true,
  );
  assert.equal(
    isStaleDeliveryNotice("2026-08-08T07:14:00.000Z", "2026-08-08T07:13:40.854Z"),
    false,
  );
  assert.equal(
    isStaleDeliveryNotice("2026-08-08T07:13:40.000Z", "2026-08-08T07:13:40.854Z"),
    false,
  );
});

test("skips invalid recipients but stops sender-side blocking", () => {
  assert.equal(shouldStopAfterDeliveryEvent("bounce"), false);
  assert.equal(shouldStopAfterDeliveryEvent("outbound_blocked"), true);
  assert.equal(shouldStopAfterDeliveryEvent("smtp_failure"), true);
});

test("validates and uniquely assigns one-year Apple Offer Codes", () => {
  const code = "EXAMPLECODE123";
  const url = `https://apps.apple.com/redeem?ctx=offercodes&id=123&code=${code}`;
  const codes = parseAppleOfferCodes(`${code},${url}\n`);
  const first = assignNextOfferCode(codes, [], {
    creator_name: "Creator",
    handle: "@creator",
    email: "Creator@Example.com",
  });
  assert.equal(first.created, true);
  assert.equal(first.assignment.email, "creator@example.com");
  const again = assignNextOfferCode(codes, [first.assignment], {
    creator_name: "Creator",
    handle: "@creator",
    email: "creator@example.com",
  });
  assert.equal(again.created, false);
  assert.equal(again.assignment.code, code);
});

test("rejects new trial assignments", () => {
  assert.throws(
    () => assignNextOfferCode([], [], { creator_name: "Creator", handle: "@creator", email: "creator@example.com" }, "trial"),
    /one-year partner offer/,
  );
});

test("classifies only clear replies into lifecycle actions", () => {
  assert.equal(classifyReplyIntent({ text: "I registered through the link" }), "affiliate_verification_pending");
  assert.equal(classifyReplyIntent({ text: "I've signed up" }), "affiliate_verification_pending");
  assert.equal(classifyReplyIntent({ text: "Done!" }), "affiliate_verification_pending");
  assert.equal(classifyReplyIntent({ text: "Yes please" }), "manual_review");
  assert.equal(classifyReplyIntent({ text: "PARTNER" }), "manual_review");
  assert.equal(classifyReplyIntent({ text: "Could you explain the pricing?" }), "manual_review");
  assert.equal(classifyReplyIntent({ text: "No thanks" }), "opt_out");
  assert.equal(classifyReplyIntent({ subject: "Automatic reply", text: "I'm away" }), "auto_reply");
  assert.equal(
    classifyReplyIntent({ text: "Could you clarify the terms?\n\nOn Aug 30, Skye wrote:\nOnce you've registered, reply joined." }),
    "manual_review",
  );
});

test("applies reply intent without automatically sending anything", () => {
  const signupLead = applyReplyIntent({ status: "sent" }, "affiliate_verification_pending", "2026-08-30T00:00:00Z");
  assert.equal(signupLead.partner_status, "verification_pending");
  assert.equal(signupLead.reply_status, "replied");
  assert.equal(signupLead.last_reply_at, "2026-08-30T00:00:00Z");

  const optedOut = applyReplyIntent({ status: "sent", approved: "yes" }, "opt_out");
  assert.equal(optedOut.status, "blocked");
  assert.equal(optedOut.approved, "no");
  assert.equal(optedOut.reply_status, "opt_out");

  const autoReply = applyReplyIntent({ status: "sent" }, "auto_reply");
  assert.equal(autoReply.reply_status, "auto_reply");
  assert.equal(autoReply.partner_status, undefined);
});

test("builds a safe Mass TikTok Email Scraper request", () => {
  const options = parseTikTokEmailArgs([
    "--keyword",
    "AI productivity",
    "--domain",
    "gmail.com",
    "--max-emails",
    "50",
  ]);
  assert.deepEqual(buildTikTokEmailInput(options), {
    keywords: ["AI productivity"],
    location: "",
    platform: "TikTok",
    customDomains: ["@gmail.com"],
    maxEmails: 50,
    engine: "legacy",
  });
  assert.equal(options.run, false);
});

test("deduplicates TikTok email results without auto-approving leads", () => {
  const results = deduplicateTikTokEmailResults([
    { email: " Creator@Example.com ", url: "https://tiktok.com/@creator" },
    { email: "creator@example.com", url: "https://tiktok.com/@duplicate" },
    { email: "second@example.com", keyword: "notes" },
  ]);
  assert.deepEqual(results, [
    {
      email: "creator@example.com",
      url: "https://tiktok.com/@creator",
      title: "",
      description: "",
      keyword: "",
      network: "TikTok",
    },
    {
      email: "second@example.com",
      url: "",
      title: "",
      description: "",
      keyword: "notes",
      network: "TikTok",
    },
  ]);
});

test("creates category-specific TikTok opener lines", () => {
  assert.equal(
    personalizationForKeywords(["faceless content creator"]),
    "I found your TikTok while researching creators who make or teach faceless content.",
  );
  assert.equal(
    personalizationForKeywords(["UGC creator tips"]),
    "I found your TikTok while researching creators who share UGC tips and workflows.",
  );
  assert.equal(
    personalizationForKeywords(["content creator tips"]),
    "I found your TikTok while researching creators who teach others how to make better content.",
  );
});

test("imports TikTok leads without guessing names or approving sends", () => {
  const imported = buildTikTokLeadRows(
    [
      {
        email: " Creator@Example.com ",
        url: "https://www.tiktok.com/@creator/video/123",
        title: "Creator tips",
        keyword: "content creator tips",
      },
      {
        email: "creator@example.com",
        url: "https://www.tiktok.com/@creator/video/456",
        keyword: "UGC creator tips",
      },
      {
        email: "existing@example.com",
        url: "https://www.tiktok.com/@existing/video/789",
        keyword: "faceless content creator",
      },
    ],
    [{ id: "existing", email: "existing@example.com" }],
  );

  assert.equal(imported.uniqueResults, 2);
  assert.equal(imported.skippedExisting, 1);
  assert.equal(imported.rows.length, 1);
  assert.equal(imported.rows[0].creator_name, "there");
  assert.equal(imported.rows[0].handle, "@creator");
  assert.equal(imported.rows[0].approved, "no");
  assert.equal(imported.rows[0].status, "pending");
  assert.equal(imported.rows[0].email_status, "unchecked");
  assert.equal(
    imported.rows[0].personalization,
    "I found your TikTok while researching creators who share UGC tips and workflows.",
  );
});

test("rejects untraceable sources and malformed scraped emails during import", () => {
  const imported = buildTikTokLeadRows([
    {
      email: "creator@example.com",
      url: "/goto?url=opaque",
      keyword: "UGC creator tips",
    },
    {
      email: ".creator@gmail.com",
      url: "https://www.tiktok.com/discover/content-creator-email",
      keyword: "content creator tips",
    },
  ]);
  assert.equal(imported.rows.length, 0);
  assert.equal(imported.skippedUntraceable, 1);
  assert.equal(imported.skippedInvalid, 1);
  assert.equal(isTraceableTikTokSource("/goto?url=opaque"), false);
  assert.equal(
    isTraceableTikTokSource("https://www.tiktok.com/discover/creator-tips"),
    false,
  );
  assert.equal(
    isTraceableTikTokSource("https://www.tiktok.com/tag/ugccreator"),
    false,
  );
  assert.equal(
    isTraceableTikTokSource("https://www.tiktok.com/@creator/video/123"),
    true,
  );
});

test("extracts TikTok handles only from profile paths", () => {
  assert.equal(
    handleFromTikTokUrl("https://www.tiktok.com/@creator/video/123"),
    "@creator",
  );
  assert.equal(handleFromTikTokUrl("https://www.tiktok.com/discover/topic"), "");
  assert.equal(handleFromTikTokUrl("https://example.com/@creator"), "");
});

test("parses a safe keyword campaign preview", () => {
  const parsed = parseTikTokCampaignArgs([
    "--keyword",
    "video script tips",
    "--max-emails",
    "50",
  ]);
  assert.deepEqual(parsed.actor.keywords, ["video script tips"]);
  assert.equal(parsed.actor.maxEmails, 50);
  assert.equal(parsed.actor.run, false);
  assert.equal(parsed.send, false);
  assert.equal(parsed.delayMin, 60);
  assert.equal(parsed.delayMax, 120);
});

test("requires paid discovery before a live keyword campaign", () => {
  assert.throws(
    () => parseTikTokCampaignArgs(["--keyword", "UGC tips", "--send"]),
    /--send requires --run/,
  );
});

test("campaign eligibility requires a safe status and explicit MX override", () => {
  assert.equal(isCampaignSendable({ status: "pending", email_status: "valid" }), true);
  assert.equal(isCampaignSendable({ status: "pending", email_status: "mx_only" }), false);
  assert.equal(
    isCampaignSendable({ status: "pending", email_status: "mx_only" }, true),
    true,
  );
  assert.equal(isCampaignSendable({ status: "blocked", email_status: "valid" }), false);
});

test("dashboard normalizes keyword input", () => {
  assert.deepEqual(parseKeywords("UGC tips, faceless creator\nUGC tips"), [
    "UGC tips",
    "faceless creator",
  ]);
});

test("dashboard summary keeps direct TikTok source and status rules", () => {
  assert.equal(isDashboardTikTokSource("https://www.tiktok.com/@creator/video/1"), true);
  assert.equal(isDashboardTikTokSource("https://www.tiktok.com/discover/creator"), false);
  const summary = summarizeLeads([
    {
      id: "tiktok-a",
      status: "pending",
      email_status: "mx_only",
      email_source: "https://www.tiktok.com/@a/video/1",
      approved: "no",
      reply_status: "",
    },
    {
      id: "tiktok-b",
      status: "sent",
      email_status: "valid",
      email_source: "https://www.tiktok.com/@b/video/2",
      approved: "no",
      reply_status: "replied",
    },
  ]);
  assert.equal(summary.eligible, 1);
  assert.equal(summary.sent, 1);
  assert.equal(summary.replied, 1);
});
