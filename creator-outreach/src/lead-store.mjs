import fs from "node:fs/promises";
import path from "node:path";
import { parse } from "csv-parse/sync";
import { stringify } from "csv-stringify/sync";
import { leadsPath } from "./config.mjs";

export const leadColumns = [
  "id",
  "creator_name",
  "handle",
  "email",
  "email_source",
  "source_keyword",
  "personalization",
  "audience_fit",
  "email_status",
  "email_checked_at",
  "approved",
  "status",
  "sent_at",
  "message_id",
  "bounce_reason",
  "reply_status",
  "reply_intent",
  "last_reply_at",
  "trial_status",
  "trial_sent_at",
  "trial_message_id",
  "partner_status",
  "partner_invite_sent_at",
  "partner_invite_message_id",
  "affiliate_signup_sent_at",
  "affiliate_signup_message_id",
  "partner_joined_at",
  "affiliate_link",
  "notes",
];

export async function readLeads(filePath = leadsPath) {
  const csv = await fs.readFile(filePath, "utf8");
  const rows = parse(csv, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });

  const seenIds = new Set();
  const seenEmails = new Set();
  for (const row of rows) {
    // Keep legacy Trial/Partner columns so historical campaigns remain readable.
    // New campaigns use only partner_status, partner_joined_at, and affiliate_link.
    for (const column of leadColumns) {
      if (!Object.hasOwn(row, column)) row[column] = "";
    }

    if (!row.id) throw new Error("Every lead needs an id.");
    if (seenIds.has(row.id)) throw new Error(`Duplicate lead id: ${row.id}`);
    seenIds.add(row.id);

    const normalizedEmail = normalizeEmail(row.email);
    if (normalizedEmail && seenEmails.has(normalizedEmail)) {
      throw new Error(`Duplicate lead email: ${row.email}`);
    }
    if (normalizedEmail) seenEmails.add(normalizedEmail);
  }
  return rows;
}

export async function writeLeads(rows, filePath = leadsPath) {
  const output = stringify(rows, {
    header: true,
    columns: leadColumns,
    quoted_match: /[,\n\r"]/,
  });
  const temporaryPath = `${filePath}.tmp`;
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(temporaryPath, output, "utf8");
  await fs.rename(temporaryPath, filePath);
}

export function normalizeEmail(value = "") {
  return value.trim().toLowerCase();
}

export function isApproved(row) {
  return row.approved?.trim().toLowerCase() === "yes";
}

export function isSendableEmailStatus(row, allowMxOnly = false) {
  const status = row.email_status?.trim().toLowerCase();
  return status === "valid" || status === "accepted" || (allowMxOnly && status === "mx_only");
}

export function selectSendableLeads(rows, { allowMxOnly = false } = {}) {
  return rows.filter(
    (row) =>
      row.status?.trim().toLowerCase() === "pending" &&
      isApproved(row) &&
      isSendableEmailStatus(row, allowMxOnly),
  );
}
