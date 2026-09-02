import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { mailConfig, outreachSubject } from "../src/config.mjs";
import { shouldStopAfterDeliveryEvent } from "../src/delivery-policy.mjs";
import {
  classifyIncomingMessage,
  fetchRecentMessages,
  isStaleDeliveryNotice,
  readSyncState,
  writeSyncState,
} from "../src/inbox.mjs";
import { readLeads, writeLeads } from "../src/lead-store.mjs";
import { applyReplyIntent, classifyReplyIntent } from "../src/lifecycle.mjs";
import { createMailer } from "../src/mailer.mjs";
import { assertSendingAllowed, pauseSending } from "../src/sending-pause.mjs";
import {
  loadHtmlTemplate,
  loadTemplate,
  renderTemplate,
} from "../src/template.mjs";

function numberArg(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  const value = Number(process.argv[index + 1]);
  if (!Number.isFinite(value)) throw new Error(`${name} needs a number.`);
  return value;
}

function stringArg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? "" : process.argv[index + 1]?.trim().toLowerCase() || "";
}

function isDirectTikTokSource(value) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase().replace(/^www\./, "");
    return host === "tiktok.com" && url.pathname.startsWith("/@");
  } catch {
    return false;
  }
}

function isEligible(row, { allowMxOnly, retryOutboundBlocked }) {
  if (!row.id?.startsWith("tiktok-") || !isDirectTikTokSource(row.email_source)) return false;
  const emailSafe = ["valid", "accepted"].includes(row.email_status) ||
    (allowMxOnly && row.email_status === "mx_only");
  if (!emailSafe) return false;
  if (row.status === "pending") return true;
  return retryOutboundBlocked &&
    row.status === "failed" &&
    row.bounce_reason === "Alibaba outbound spam filter blocked the message before delivery";
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const liveSend = process.argv.includes("--send");
const allowMxOnly = process.argv.includes("--allow-mx-only");
const retryOutboundBlocked = process.argv.includes("--retry-outbound-blocked");
const limit = Math.min(Math.max(Math.floor(numberArg("--limit", 100)), 1), 100);
const delayMin = numberArg("--delay-min", 60);
const delayMax = numberArg("--delay-max", 120);
const pollSeconds = numberArg("--poll-seconds", 20);
const targetEmail = stringArg("--email");
const sourceKeyword = stringArg("--keyword");
if (delayMin < 20 || delayMax < delayMin) throw new Error("Delay must be at least 20 seconds.");
if (pollSeconds < 10 || pollSeconds > 60) throw new Error("Poll interval must be 10-60 seconds.");

const rows = await readLeads();
const candidates = rows
  .filter((row) => isEligible(row, { allowMxOnly, retryOutboundBlocked }))
  .filter((row) => !targetEmail || row.email.toLowerCase() === targetEmail)
  .filter((row) => !sourceKeyword || row.source_keyword.toLowerCase() === sourceKeyword)
  .slice(0, limit);

console.log(`Prepared ${candidates.length} monitored email(s).`);
console.log(`- First attempts: ${candidates.filter((row) => row.status === "pending").length}`);
console.log(`- Sender-blocked retries: ${candidates.filter((row) => row.status === "failed").length}`);
console.log(`- Delay: ${delayMin}-${delayMax}s; inbox poll: every ${pollSeconds}s`);

if (!liveSend) {
  console.log("Dry run only. No email was sent.");
  process.exit(0);
}
if (!candidates.length) process.exit(0);
const isSingleTargetedRetry =
  retryOutboundBlocked &&
  targetEmail &&
  candidates.length === 1 &&
  candidates[0].email.toLowerCase() === targetEmail &&
  candidates[0].status === "failed";
if (isSingleTargetedRetry) {
  console.log("Existing campaign pause retained; allowing this one explicitly targeted retry only.");
} else {
  await assertSendingAllowed();
}

const rl = readline.createInterface({ input, output });
const phrase = `SEND ${candidates.length}`;
const answer = await rl.question(`Type ${phrase} to start monitored sending: `);
rl.close();
if (answer.trim() !== phrase) {
  console.log("Confirmation did not match. Nothing was sent.");
  process.exit(1);
}

for (const row of candidates) row.approved = "yes";
await writeLeads(rows);

const campaignStartedAt = new Date();
const state = await readSyncState();
const processedMessageIds = new Set(state.processedMessageIds || []);
const textTemplate = await loadTemplate();
const htmlTemplate = await loadHtmlTemplate();
const config = mailConfig();
const transporter = createMailer();
let stopReason = "";

async function syncNewMail() {
  const messages = await fetchRecentMessages({
    since: new Date(campaignStartedAt.getTime() - 5 * 60 * 1000),
    processedMessageIds: [...processedMessageIds],
  });
  let changed = false;
  let detectedFailure = "";

  for (const message of messages) {
    processedMessageIds.add(message.messageId);
    const classification = classifyIncomingMessage(message.parsed, rows);
    if (!classification.leadId) continue;
    const row = rows.find((candidate) => candidate.id === classification.leadId);
    if (!row) continue;
    if (
      ["bounce", "outbound_blocked"].includes(classification.type) &&
      isStaleDeliveryNotice(message.parsed.date, row.sent_at)
    ) {
      continue;
    }

    if (classification.type === "bounce") {
      row.status = "bounced";
      row.email_status = "invalid";
      row.bounce_reason = classification.reason;
      row.approved = "no";
      console.warn(`↷ Skipped bounced address: ${row.email} (${classification.reason})`);
      changed = true;
    } else if (classification.type === "outbound_blocked") {
      row.status = "failed";
      row.bounce_reason = classification.reason;
      row.approved = "no";
      if (shouldStopAfterDeliveryEvent(classification.type)) {
        detectedFailure = `${row.email}: ${classification.reason}`;
      }
      changed = true;
    } else if (classification.type === "reply") {
      applyReplyIntent(row, classifyReplyIntent(message.parsed, row));
      changed = true;
    }
  }

  state.processedMessageIds = [...processedMessageIds].slice(-2000);
  state.lastSyncAt = new Date().toISOString();
  if (changed) await writeLeads(rows);
  await writeSyncState(state);
  return detectedFailure;
}

async function monitorFor(seconds) {
  const deadline = Date.now() + seconds * 1000;
  while (Date.now() < deadline) {
    await sleep(Math.min(pollSeconds * 1000, deadline - Date.now()));
    const failure = await syncNewMail();
    if (failure) return failure;
  }
  return "";
}

try {
  await transporter.verify();
  for (let index = 0; index < candidates.length; index += 1) {
    const lead = candidates[index];
    const row = rows.find((candidate) => candidate.id === lead.id);
    try {
      const info = await transporter.sendMail({
        from: `"Skye Lu" <${config.user}>`,
        replyTo: config.user,
        to: lead.email,
        subject: outreachSubject,
        text: renderTemplate(textTemplate, lead),
        html: renderTemplate(htmlTemplate, lead),
      });
      row.status = "sent";
      row.sent_at = new Date().toISOString();
      row.message_id = info.messageId || "";
      row.bounce_reason = "";
      row.approved = "no";
      row.notes = [row.notes, "Sent by monitored TikTok campaign"].filter(Boolean).join(" | ");
      await writeLeads(rows);
      console.log(`✓ ${index + 1}/${candidates.length} queued: ${lead.email}`);
    } catch (error) {
      row.status = "failed";
      row.approved = "no";
      row.notes = [row.notes, `SMTP send failed: ${error.message}`].filter(Boolean).join(" | ");
      await writeLeads(rows);
      stopReason = `${lead.email}: SMTP send failed (${error.message})`;
      break;
    }

    const monitorSeconds = Math.round(delayMin + Math.random() * (delayMax - delayMin));
    console.log(`Monitoring inbox for ${monitorSeconds}s before the next message...`);
    stopReason = await monitorFor(monitorSeconds);
    if (stopReason) break;
  }
} finally {
  transporter.close();
  for (const row of candidates) row.approved = "no";
  await writeLeads(rows);
  const reason = stopReason
    ? `Monitored campaign stopped after a new delivery failure: ${stopReason}`
    : "Monitored campaign finished; sending is paused pending review.";
  await pauseSending(reason);
}

if (stopReason) {
  console.error(`STOPPED: ${stopReason}`);
  process.exit(2);
}
console.log("Monitored campaign finished without a detected bounce.");
