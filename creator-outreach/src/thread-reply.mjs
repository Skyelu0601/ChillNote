import fs from "node:fs/promises";
import { fetchRecentMessages } from "./inbox.mjs";
import { normalizeEmail } from "./lead-store.mjs";

export function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function textToHtml(text) {
  const linked = escapeHtml(text).replace(
    /(https:\/\/[^\s<]+)/g,
    '<a href="$1" style="color:#1a5fb4;">$1</a>',
  );
  return `<div style="font-family:'Times New Roman',Times,serif;font-size:16px;line-height:1.5;color:#111;white-space:pre-line;">${linked}</div>`;
}

export async function renderReplyTemplate(filePath, values) {
  let body = await fs.readFile(filePath, "utf8");
  for (const [key, value] of Object.entries(values)) {
    body = body.replaceAll(`{{${key}}}`, String(value));
  }
  const unresolved = body.match(/\{\{[^}]+\}\}/g);
  if (unresolved) throw new Error(`Unresolved reply placeholders: ${unresolved.join(", ")}`);
  return body.trim();
}

export async function latestCreatorReply(email, days = 60) {
  const messages = await fetchRecentMessages({
    since: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
    processedMessageIds: [],
  });
  return messages
    .filter(({ parsed }) => normalizeEmail(parsed.from?.value?.[0]?.address || "") === email)
    .sort((a, b) => new Date(b.parsed.date || 0) - new Date(a.parsed.date || 0))[0] || null;
}
