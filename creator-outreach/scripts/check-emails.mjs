import { readLeads, writeLeads } from "../src/lead-store.mjs";
import { validateEmail } from "../src/email-validation.mjs";

const checkAll = process.argv.includes("--all");
const includeHistory = process.argv.includes("--include-history");
const rows = await readLeads();
const apiKey = process.env.ZEROBOUNCE_API_KEY?.trim() || "";
let checked = 0;

for (const row of rows) {
  if (!includeHistory && row.status?.toLowerCase() !== "pending") continue;
  const currentStatus = row.email_status?.toLowerCase();
  if (!checkAll && currentStatus && currentStatus !== "unchecked" && currentStatus !== "unknown") {
    continue;
  }

  const result = await validateEmail(row.email, apiKey);
  row.email_status = result.status;
  row.email_checked_at = new Date().toISOString();
  if (result.status === "invalid" || result.status === "risky") {
    row.approved = "no";
    if (row.status === "pending") row.status = "blocked";
  }
  row.notes = [row.notes, `Email check: ${result.reason}`].filter(Boolean).join(" | ");
  console.log(`${row.email}: ${result.status} (${result.reason})`);
  checked += 1;
}

if (checked) await writeLeads(rows);
console.log(
  checked
    ? `Updated ${checked} lead(s).`
    : "No unchecked leads. Use --all to recheck every address.",
);
if (!apiKey) {
  console.log("ZeroBounce is not configured; valid domains are labeled mx_only, not fully verified.");
}
