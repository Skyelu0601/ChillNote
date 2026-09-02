import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { mailConfig, outreachSubject } from "../src/config.mjs";
import {
  readLeads,
  selectSendableLeads,
  writeLeads,
} from "../src/lead-store.mjs";
import { createMailer } from "../src/mailer.mjs";
import { assertSendingAllowed } from "../src/sending-pause.mjs";
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

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const liveSend = process.argv.includes("--send");
if (liveSend) await assertSendingAllowed();
const allowMxOnly = process.argv.includes("--allow-mx-only");
const requestedLimit = numberArg("--limit", 10);
const bulkConfirmed = process.argv.includes("--bulk-confirmed");
const hardLimit = bulkConfirmed ? 105 : 10;
const limit = Math.min(Math.max(Math.floor(requestedLimit), 1), hardLimit);
const delayMin = numberArg("--delay-min", 60);
const delayMax = numberArg("--delay-max", 120);
if (delayMin < 0 || delayMax < delayMin) throw new Error("Invalid delay range.");

const rows = await readLeads();
const template = await loadTemplate();
const htmlTemplate = await loadHtmlTemplate();
const leads = selectSendableLeads(rows, { allowMxOnly }).slice(0, limit);

if (!leads.length) {
  console.log("No sendable leads.");
  console.log("Required: status=pending, approved=yes, and email_status=valid or accepted.");
  process.exit(0);
}

console.log(`Prepared ${leads.length} email(s):`);
for (const lead of leads) {
  console.log(`- ${lead.creator_name} <${lead.email}> [${lead.email_status}]`);
}

if (!liveSend) {
  console.log("\nDry run only. No email was sent.");
  console.log("Run npm run preview first, then use: npm run send -- --send");
  process.exit(0);
}

const rl = readline.createInterface({ input, output });
const phrase = `SEND ${leads.length}`;
const answer = await rl.question(`\nType ${phrase} to send these emails: `);
rl.close();
if (answer.trim() !== phrase) {
  console.log("Confirmation did not match. Nothing was sent.");
  process.exit(1);
}

const config = mailConfig();
const transporter = createMailer();
await transporter.verify();

for (let index = 0; index < leads.length; index += 1) {
  const lead = leads[index];
  const row = rows.find((candidate) => candidate.id === lead.id);
  try {
    const info = await transporter.sendMail({
      from: `"Skye Lu" <${config.user}>`,
      replyTo: config.user,
      to: lead.email,
      subject: outreachSubject,
      text: renderTemplate(template, lead),
      html: renderTemplate(htmlTemplate, lead),
    });
    row.status = "sent";
    row.sent_at = new Date().toISOString();
    row.message_id = info.messageId || "";
    row.bounce_reason = "";
    console.log(`✓ Sent to ${lead.creator_name} <${lead.email}>`);
  } catch (error) {
    row.status = "failed";
    row.notes = [row.notes, `SMTP send failed: ${error.message}`].filter(Boolean).join(" | ");
    console.error(`✗ Failed for ${lead.creator_name} <${lead.email}>: ${error.message}`);
  }

  await writeLeads(rows);
  if (index < leads.length - 1) {
    const delaySeconds = Math.round(delayMin + Math.random() * (delayMax - delayMin));
    console.log(`Waiting ${delaySeconds}s before the next message...`);
    await sleep(delaySeconds * 1000);
  }
}

transporter.close();
console.log("Finished. Run npm run sync later to record replies and bounces.");
