import { readLeads, writeLeads } from "../src/lead-store.mjs";

const rows = await readLeads();
let paused = 0;
for (const row of rows) {
  if (row.id.startsWith("tiktok-") && row.status === "pending" && row.approved === "yes") {
    row.approved = "no";
    paused += 1;
  }
}
if (paused) await writeLeads(rows);
console.log(`Paused ${paused} pending TikTok lead(s). No email was sent.`);
