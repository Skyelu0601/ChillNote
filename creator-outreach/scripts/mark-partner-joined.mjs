import { normalizeEmail, readLeads, writeLeads } from "../src/lead-store.mjs";

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? "" : process.argv[index + 1]?.trim() || "";
}

const email = normalizeEmail(arg("--email"));
const affiliateLink = arg("--affiliate-link");
const confirmation = arg("--confirm");
if (!email || !affiliateLink) throw new Error("Required: --email and --affiliate-link.");
if (confirmation !== `MARK PARTNER JOINED ${email}`) {
  throw new Error(`Confirmation required: --confirm \"MARK PARTNER JOINED ${email}\"`);
}
new URL(affiliateLink);

const rows = await readLeads();
const lead = rows.find((row) => normalizeEmail(row.email) === email);
if (!lead || !["requested", "signup_sent", "verification_pending"].includes(lead.partner_status)) {
  throw new Error("The creator has not reported completing Affiliate registration.");
}
lead.partner_status = "joined";
lead.partner_joined_at = new Date().toISOString();
lead.affiliate_link = affiliateLink;
lead.notes = [lead.notes, `Affiliate joined ${lead.partner_joined_at}`].filter(Boolean).join(" | ");
await writeLeads(rows);
console.log(`Partner membership recorded for ${lead.creator_name} <${email}>.`);
