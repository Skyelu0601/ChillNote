import { readLeads, writeLeads } from "../src/lead-store.mjs";

function confirmationArg() {
  const index = process.argv.indexOf("--confirm");
  return index === -1 ? "" : process.argv[index + 1] || "";
}

const rows = await readLeads();
const candidates = rows.filter(
  (row) =>
    row.id.startsWith("tiktok-") &&
    row.status === "pending" &&
    row.approved !== "yes" &&
    ["valid", "accepted", "mx_only"].includes(row.email_status),
);

if (!candidates.length) {
  console.log("No unapproved pending TikTok leads found.");
  process.exit(0);
}

const phrase = `APPROVE ${candidates.length}`;
if (confirmationArg() !== phrase) {
  console.log(`No changes made. To approve this exact queue, pass --confirm "${phrase}".`);
  process.exit(1);
}

for (const row of candidates) row.approved = "yes";
await writeLeads(rows);
console.log(`Approved ${candidates.length} TikTok lead(s). No email was sent.`);
