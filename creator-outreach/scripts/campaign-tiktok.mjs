import fs from "node:fs/promises";
import path from "node:path";
import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { ApifyClient } from "apify-client";
import { stringify } from "csv-stringify/sync";
import {
  apifyConfig,
  mailConfig,
  outreachSubject,
  previewDir,
  toolRoot,
} from "../src/config.mjs";
import { validateEmail } from "../src/email-validation.mjs";
import { readLeads, writeLeads } from "../src/lead-store.mjs";
import { createMailer } from "../src/mailer.mjs";
import { assertSendingAllowed } from "../src/sending-pause.mjs";
import {
  buildTikTokEmailInput,
  deduplicateTikTokEmailResults,
  massTikTokEmailActor,
} from "../src/tiktok-email.mjs";
import { buildTikTokLeadRows } from "../src/tiktok-lead-import.mjs";
import {
  isCampaignSendable,
  parseTikTokCampaignArgs,
} from "../src/tiktok-campaign.mjs";
import {
  loadHtmlTemplate,
  loadTemplate,
  renderTemplate,
} from "../src/template.mjs";

const usage = `Usage:
  npm run campaign:tiktok -- --keyword "UGC creator tips" [options]

Options:
  --keyword <text>       Search keyword; repeat for multiple keywords
  --domain <domain>      Email domain; repeat to override defaults
  --location <text>     Optional location filter
  --max-emails <n>      Requested result cap (default: 20)
  --run                  Start the paid Apify Actor
  --send                 After filtering and validation, offer to send this campaign
  --allow-mx-only        Deliberately allow domain-only validated addresses
  --delay-min <seconds>  Minimum send delay (default: 60)
  --delay-max <seconds>  Maximum send delay (default: 120)
  --help                 Show this help

Without --run, this is a free preview. Without --send, results are imported as
unapproved and previewed, but no email is sent.`;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function timestampSlug() {
  return new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
}

let options;
try {
  options = parseTikTokCampaignArgs(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  console.error(`\n${usage}`);
  process.exit(1);
}

if (options.actor.help) {
  console.log(usage);
  process.exit(0);
}

const actorInput = buildTikTokEmailInput(options.actor);
if (options.send) await assertSendingAllowed();
const estimatedActorFee = options.actor.maxEmails * 0.0025;
console.log(`Actor: ${massTikTokEmailActor}`);
console.log(JSON.stringify(actorInput, null, 2));
console.log(`Maximum advertised result fee on the FREE tier: about $${estimatedActorFee.toFixed(2)}`);
console.log("Permanent filter: only complete TikTok /@username sources are accepted.");

if (!options.actor.run) {
  console.log("\nPreview only. Add --run to start paid discovery.");
  process.exit(0);
}

const client = new ApifyClient(apifyConfig());
console.log("\nStarting paid Apify discovery...");
const run = await client.actor(massTikTokEmailActor).call(actorInput);
if (!run?.defaultDatasetId) {
  throw new Error(`Actor run ${run?.id || "unknown"} did not return a dataset.`);
}

const { items } = await client.dataset(run.defaultDatasetId).listItems();
const results = deduplicateTikTokEmailResults(items);
const timestamp = timestampSlug();
const outputDir = path.join(toolRoot, "data", "tiktok-email-runs");
const basePath = path.join(outputDir, `tiktok-emails-${timestamp}`);
await fs.mkdir(outputDir, { recursive: true });
await Promise.all([
  fs.writeFile(`${basePath}.json`, `${JSON.stringify(results, null, 2)}\n`, "utf8"),
  fs.writeFile(
    `${basePath}.csv`,
    stringify(results, {
      header: true,
      columns: ["email", "url", "title", "description", "keyword", "network"],
    }),
    "utf8",
  ),
]);

const existingRows = await readLeads();
const imported = buildTikTokLeadRows(results, existingRows);
console.log(`Raw results: ${items.length}; unique emails: ${imported.uniqueResults}.`);
console.log(`Rejected non-/@username sources: ${imported.skippedUntraceable}.`);
console.log(`Rejected malformed emails: ${imported.skippedInvalid}.`);
console.log(`Already known emails: ${imported.skippedExisting}.`);
console.log(`New leads: ${imported.rows.length}.`);

if (!imported.rows.length) {
  console.log("No new qualified leads. Nothing was approved or sent.");
  process.exit(0);
}

const apiKey = process.env.ZEROBOUNCE_API_KEY?.trim() || "";
for (const row of imported.rows) {
  try {
    const result = await validateEmail(row.email, apiKey);
    row.email_status = result.status;
    row.email_checked_at = new Date().toISOString();
    row.notes = [row.notes, `Email check: ${result.reason}`].filter(Boolean).join(" | ");
    if (["invalid", "risky", "unknown"].includes(result.status)) row.status = "blocked";
  } catch (error) {
    row.email_status = "unknown";
    row.email_checked_at = new Date().toISOString();
    row.status = "blocked";
    row.notes = [row.notes, `Email check failed: ${error.message}`].filter(Boolean).join(" | ");
  }
}

const allRows = [...existingRows, ...imported.rows];
await writeLeads(allRows);

const textTemplate = await loadTemplate();
const htmlTemplate = await loadHtmlTemplate();
const campaignPreviewDir = path.join(previewDir, `campaign-${timestamp}`);
await fs.mkdir(campaignPreviewDir, { recursive: true });
for (const row of imported.rows) {
  const textBody = renderTemplate(textTemplate, row);
  const htmlBody = renderTemplate(htmlTemplate, row);
  await Promise.all([
    fs.writeFile(
      path.join(campaignPreviewDir, `${row.id}.txt`),
      `To: ${row.email}\nSubject: ${outreachSubject}\n\n${textBody}\n`,
      "utf8",
    ),
    fs.writeFile(path.join(campaignPreviewDir, `${row.id}.html`), htmlBody, "utf8"),
  ]);
}
console.log(`Saved ${imported.rows.length} text/HTML preview pair(s): ${campaignPreviewDir}`);

const eligible = imported.rows.filter((row) =>
  isCampaignSendable(row, options.allowMxOnly),
);
console.log(`Eligible for this campaign: ${eligible.length}.`);
if (!apiKey) console.log("ZeroBounce is not configured; successful domain checks are mx_only.");

if (!options.send) {
  console.log("Imported as approved=no. Add --send on a future campaign to offer live sending.");
  process.exit(0);
}
if (!eligible.length) {
  console.log("No sendable new leads. Nothing was approved or sent.");
  process.exit(0);
}

const rl = readline.createInterface({ input, output });
const phrase = `SEND ${eligible.length}`;
const answer = await rl.question(`Type ${phrase} to approve and send this new campaign: `);
rl.close();
if (answer.trim() !== phrase) {
  console.log("Confirmation did not match. Leads remain unapproved and no email was sent.");
  process.exit(1);
}

for (const row of eligible) row.approved = "yes";
await writeLeads(allRows);

const config = mailConfig();
const transporter = createMailer();
await transporter.verify();
for (let index = 0; index < eligible.length; index += 1) {
  const row = eligible[index];
  try {
    const info = await transporter.sendMail({
      from: `"Skye Lu" <${config.user}>`,
      replyTo: config.user,
      to: row.email,
      subject: outreachSubject,
      text: renderTemplate(textTemplate, row),
      html: renderTemplate(htmlTemplate, row),
    });
    row.status = "sent";
    row.sent_at = new Date().toISOString();
    row.message_id = info.messageId || "";
    row.bounce_reason = "";
    console.log(`✓ Sent to ${row.email}`);
  } catch (error) {
    row.status = "failed";
    row.notes = [row.notes, `SMTP send failed: ${error.message}`].filter(Boolean).join(" | ");
    console.error(`✗ Failed ${row.email}: ${error.message}`);
  }
  await writeLeads(allRows);
  if (index < eligible.length - 1) {
    const seconds = Math.round(
      options.delayMin + Math.random() * (options.delayMax - options.delayMin),
    );
    console.log(`Waiting ${seconds}s...`);
    await sleep(seconds * 1000);
  }
}
transporter.close();
console.log("Campaign finished. Run npm run sync later for replies and bounces.");
