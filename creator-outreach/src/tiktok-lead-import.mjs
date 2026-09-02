import crypto from "node:crypto";
import { normalizeEmail } from "./lead-store.mjs";
import { isValidEmailSyntax } from "./email-validation.mjs";

const openerBySegment = {
  faceless:
    "I found your TikTok while researching creators who make or teach faceless content.",
  ugc: "I found your TikTok while researching creators who share UGC tips and workflows.",
  creator:
    "I found your TikTok while researching creators who teach others how to make better content.",
  default:
    "I found your TikTok while researching creators who share content tips and workflows.",
};

export function segmentForKeywords(keywords = []) {
  const combined = keywords.join(" ").toLowerCase();
  if (combined.includes("faceless")) return "faceless";
  if (combined.includes("ugc")) return "ugc";
  if (combined.includes("content creator")) return "creator";
  return "default";
}

export function personalizationForKeywords(keywords = []) {
  return openerBySegment[segmentForKeywords(keywords)];
}

export function handleFromTikTokUrl(value = "") {
  try {
    const url = new URL(value);
    if (!/(^|\.)tiktok\.com$/i.test(url.hostname)) return "";
    const match = url.pathname.match(/^\/@([^/]+)/);
    return match ? `@${decodeURIComponent(match[1])}` : "";
  } catch {
    return "";
  }
}

export function isTraceableTikTokSource(value = "") {
  try {
    const url = new URL(value);
    if (!/(^|\.)tiktok\.com$/i.test(url.hostname)) return false;
    const firstPathPart = url.pathname.split("/").filter(Boolean)[0] || "";
    return firstPathPart.startsWith("@") && firstPathPart.length > 1;
  } catch {
    return false;
  }
}

function sourceScore(row) {
  const url = row.url || "";
  return (
    (handleFromTikTokUrl(url) ? 4 : 0) +
    (/\/video\//.test(url) ? 1 : 0) +
    (row.title ? 1 : 0) +
    (row.description ? 1 : 0)
  );
}

function compactText(value = "", limit = 180) {
  const compact = String(value).replace(/\s+/g, " ").trim();
  return compact.length > limit ? `${compact.slice(0, limit - 1)}…` : compact;
}

function leadId(email, handle, existingIds) {
  const readable = (handle || email.split("@")[0] || "creator")
    .replace(/^@/, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 30) || "creator";
  const hash = crypto.createHash("sha256").update(email).digest("hex").slice(0, 8);
  let candidate = `tiktok-${readable}-${hash}`;
  let suffix = 2;
  while (existingIds.has(candidate)) {
    candidate = `tiktok-${readable}-${hash}-${suffix}`;
    suffix += 1;
  }
  existingIds.add(candidate);
  return candidate;
}

export function mergeTikTokResults(results = []) {
  const merged = new Map();
  for (const raw of results) {
    const email = normalizeEmail(raw.email || "");
    if (!email) continue;
    const keyword = compactText(raw.keyword || "", 100);
    const candidate = {
      email,
      url: compactText(raw.url || "", 500),
      title: compactText(raw.title || ""),
      description: compactText(raw.description || "", 500),
      keyword,
      network: compactText(raw.network || "TikTok", 50),
    };
    const current = merged.get(email);
    if (!current) {
      merged.set(email, { ...candidate, keywords: new Set(keyword ? [keyword] : []) });
      continue;
    }
    if (keyword) current.keywords.add(keyword);
    if (sourceScore(candidate) > sourceScore(current)) {
      const keywords = current.keywords;
      merged.set(email, { ...candidate, keywords });
    }
  }

  return [...merged.values()].map((row) => ({
    ...row,
    keywords: [...row.keywords].sort(),
  }));
}

export function buildTikTokLeadRows(results, existingRows = []) {
  const existingEmails = new Set(existingRows.map((row) => normalizeEmail(row.email || "")));
  const existingIds = new Set(existingRows.map((row) => row.id));
  const merged = mergeTikTokResults(results);
  const imported = [];
  let skippedExisting = 0;
  let skippedUntraceable = 0;
  let skippedInvalid = 0;

  for (const result of merged) {
    if (!isValidEmailSyntax(result.email)) {
      skippedInvalid += 1;
      continue;
    }
    if (!isTraceableTikTokSource(result.url)) {
      skippedUntraceable += 1;
      continue;
    }
    if (existingEmails.has(result.email)) {
      skippedExisting += 1;
      continue;
    }
    existingEmails.add(result.email);
    const handle = handleFromTikTokUrl(result.url);
    const keywords = result.keywords.length
      ? result.keywords
      : [result.keyword].filter(Boolean);
    const noteParts = [
      "Imported from Mass TikTok Email Scraper",
      keywords.length ? `Search keywords: ${keywords.join(", ")}` : "",
      result.title ? `Search title: ${result.title}` : "",
    ].filter(Boolean);

    imported.push({
      id: leadId(result.email, handle, existingIds),
      creator_name: "there",
      handle,
      email: result.email,
      email_source: result.url,
      source_keyword: keywords.join(", "),
      personalization: personalizationForKeywords(keywords),
      audience_fit: "",
      email_status: "unchecked",
      email_checked_at: "",
      approved: "no",
      status: "pending",
      sent_at: "",
      message_id: "",
      bounce_reason: "",
      reply_status: "",
      last_reply_at: "",
      notes: noteParts.join(" | "),
    });
  }

  return {
    rows: imported,
    uniqueResults: merged.length,
    skippedExisting,
    skippedUntraceable,
    skippedInvalid,
  };
}
