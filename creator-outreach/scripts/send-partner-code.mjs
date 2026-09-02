import { readAssignmentLedger, writeAssignmentLedger } from "../src/assignment-store.mjs";
import { mailConfig, outreachSubject, partnerCodeTemplatePath } from "../src/config.mjs";
import { normalizeEmail, readLeads, writeLeads } from "../src/lead-store.mjs";
import { createMailer } from "../src/mailer.mjs";
import { findOfferCodeAssignment } from "../src/offer-codes.mjs";
import { latestCreatorReply, renderReplyTemplate, textToHtml } from "../src/thread-reply.mjs";

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? "" : process.argv[index + 1]?.trim() || "";
}

const email = normalizeEmail(arg("--email"));
const confirmation = arg("--confirm");
if (!email) throw new Error("Required: --email.");
if (confirmation !== `SEND PARTNER CODE ${email}`) {
  throw new Error(`Confirmation required: --confirm \"SEND PARTNER CODE ${email}\"`);
}

const ledger = await readAssignmentLedger();
const assignment = findOfferCodeAssignment(ledger.assignments, email, "partner");
if (!assignment) throw new Error("No assigned partner code exists for this creator.");
if (assignment.status === "sent" || assignment.sent_at) throw new Error("This partner code has already been sent.");

const rows = await readLeads();
const lead = rows.find((row) => normalizeEmail(row.email) === email);
if (!lead || lead.partner_status !== "code_assigned" || !lead.affiliate_link) {
  throw new Error("The creator must join the affiliate program before the one-year code is sent.");
}

const latestReply = await latestCreatorReply(email);
if (!latestReply?.messageId) throw new Error("Could not find the creator's inbound reply, so no email was sent.");
const body = await renderReplyTemplate(partnerCodeTemplatePath, {
  creator_name: assignment.creator_name,
  creator_pass_code: assignment.code,
  redemption_url: assignment.redemption_url,
  affiliate_link: lead.affiliate_link,
});
const transporter = createMailer();
try {
  const sender = mailConfig().user;
  const result = await transporter.sendMail({
    from: sender,
    to: email,
    replyTo: sender,
    subject: `Re: ${outreachSubject}`,
    text: body,
    html: textToHtml(body),
    inReplyTo: latestReply.messageId,
    references: [lead.message_id, latestReply.messageId].filter(Boolean),
  });
  const sentAt = new Date().toISOString();
  assignment.status = "sent";
  assignment.sent_at = sentAt;
  assignment.message_id = result.messageId;
  lead.partner_status = "code_sent";
  lead.notes = [lead.notes, `One-year partner code sent ${sentAt}`].filter(Boolean).join(" | ");
  await writeAssignmentLedger(ledger);
  await writeLeads(rows);
  console.log(`Partner code sent to ${assignment.creator_name} <${email}>.`);
} finally {
  transporter.close();
}
