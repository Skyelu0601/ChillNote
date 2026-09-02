import fs from "node:fs/promises";
import path from "node:path";
import { outreachSubject, previewDir } from "../src/config.mjs";
import { readLeads } from "../src/lead-store.mjs";
import { loadTemplate, renderTemplate } from "../src/template.mjs";

const shouldWrite = process.argv.includes("--write");
const showAllPending = process.argv.includes("--all-pending");
const rows = await readLeads();
const template = await loadTemplate();
const leads = rows.filter((row) => {
  if (showAllPending) return row.status === "pending";
  return row.status === "pending" && row.approved?.toLowerCase() === "yes";
});

if (!leads.length) {
  console.log("No pending approved leads to preview.");
  console.log("Set approved=yes on a pending row in data/leads.csv when it is ready.");
  process.exit(0);
}

if (shouldWrite) await fs.mkdir(previewDir, { recursive: true });

for (const lead of leads) {
  const body = renderTemplate(template, lead);
  const content = `To: ${lead.email}\nSubject: ${outreachSubject}\n\n${body}\n`;
  console.log(`\n${"=".repeat(72)}\n${content}`);
  if (shouldWrite) {
    await fs.writeFile(path.join(previewDir, `${lead.id}.txt`), content, "utf8");
  }
}

if (shouldWrite) console.log(`\nWrote ${leads.length} preview file(s) to ${previewDir}`);
