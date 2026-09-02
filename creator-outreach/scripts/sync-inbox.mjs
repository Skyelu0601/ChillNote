import {
  classifyIncomingMessage,
  fetchRecentMessages,
  isStaleDeliveryNotice,
  readSyncState,
  writeSyncState,
} from "../src/inbox.mjs";
import { readLeads, writeLeads } from "../src/lead-store.mjs";
import { applyReplyIntent, classifyReplyIntent } from "../src/lifecycle.mjs";

function dateArg() {
  const index = process.argv.indexOf("--days");
  const days = index === -1 ? 14 : Number(process.argv[index + 1]);
  if (!Number.isFinite(days) || days < 1 || days > 90) {
    throw new Error("--days must be between 1 and 90.");
  }
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

const rows = await readLeads();
const state = await readSyncState();
const reprocess = process.argv.includes("--reprocess");
const since = state.lastSyncAt
  ? new Date(new Date(state.lastSyncAt).getTime() - 24 * 60 * 60 * 1000)
  : dateArg();
const messages = await fetchRecentMessages({
  since,
  processedMessageIds: reprocess ? [] : state.processedMessageIds,
});

let changed = false;
for (const message of messages) {
  const classification = classifyIncomingMessage(message.parsed, rows);
  if (classification.leadId) {
    const row = rows.find((candidate) => candidate.id === classification.leadId);
    if (
      ["bounce", "outbound_blocked"].includes(classification.type) &&
      isStaleDeliveryNotice(message.parsed.date, row.sent_at)
    ) {
      console.log(`Ignored stale delivery notice: ${row.email}`);
      state.processedMessageIds.push(message.messageId);
      continue;
    }
    if (classification.type === "bounce") {
      row.status = "bounced";
      row.email_status = "invalid";
      row.bounce_reason = classification.reason;
      row.approved = "no";
      console.log(`Bounce: ${row.email} (${classification.reason})`);
      changed = true;
    } else if (classification.type === "outbound_blocked") {
      row.status = "failed";
      if (row.email_status === "invalid") row.email_status = "mx_only";
      row.bounce_reason = classification.reason;
      row.approved = "no";
      const note = `Delivery failed: ${classification.reason}`;
      if (!row.notes?.includes(note)) {
        row.notes = [row.notes, note].filter(Boolean).join(" | ");
      }
      console.log(`Outbound blocked: ${row.email}`);
      changed = true;
    } else if (classification.type === "reply") {
      const intent = classifyReplyIntent(message.parsed, row);
      applyReplyIntent(row, intent);
      console.log(`Reply: ${row.creator_name} <${row.email}> (${intent})`);
      changed = true;
    }
  }
  state.processedMessageIds.push(message.messageId);
}

state.processedMessageIds = [...new Set(state.processedMessageIds)].slice(-2000);
state.lastSyncAt = new Date().toISOString();
if (changed) await writeLeads(rows);
await writeSyncState(state);
console.log(`Checked ${messages.length} new message(s); lead updates: ${changed ? "yes" : "none"}.`);
