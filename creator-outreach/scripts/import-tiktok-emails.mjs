import fs from "node:fs/promises";
import path from "node:path";
import { parse } from "csv-parse/sync";
import { readLeads, writeLeads } from "../src/lead-store.mjs";
import { toolRoot } from "../src/config.mjs";
import { buildTikTokLeadRows } from "../src/tiktok-lead-import.mjs";

function inputArgs(argv) {
  const inputs = [];
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] !== "--input") continue;
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error("--input needs a CSV path.");
    inputs.push(path.resolve(value));
    index += 1;
  }
  return inputs;
}

async function defaultInputs() {
  const directory = path.join(toolRoot, "data", "tiktok-email-runs");
  const entries = await fs.readdir(directory);
  return entries
    .filter((entry) => entry.endsWith(".csv"))
    .sort()
    .map((entry) => path.join(directory, entry));
}

const write = process.argv.includes("--write");
const requestedInputs = inputArgs(process.argv.slice(2));
const inputs = requestedInputs.length ? requestedInputs : await defaultInputs();
if (!inputs.length) throw new Error("No TikTok email CSV files found.");

const results = [];
for (const input of inputs) {
  const csv = await fs.readFile(input, "utf8");
  results.push(...parse(csv, { columns: true, skip_empty_lines: true, trim: true }));
}

const existing = await readLeads();
const imported = buildTikTokLeadRows(results, existing);

console.log(`Read ${results.length} scraped row(s) from ${inputs.length} file(s).`);
console.log(`Unique scraped emails: ${imported.uniqueResults}.`);
console.log(`Skipped sources without a direct /@username path: ${imported.skippedUntraceable}.`);
console.log(`Skipped invalid email syntax: ${imported.skippedInvalid}.`);
console.log(`Already present in leads.csv: ${imported.skippedExisting}.`);
console.log(`New leads ready to import: ${imported.rows.length}.`);
console.log("Safety defaults: approved=no, status=pending, email_status=unchecked.");

const keywordCounts = new Map();
for (const row of imported.rows) {
  const key = row.source_keyword || "unclassified";
  keywordCounts.set(key, (keywordCounts.get(key) || 0) + 1);
}
for (const [keyword, count] of [...keywordCounts].sort()) {
  console.log(`- ${keyword}: ${count}`);
}

if (!write) {
  console.log("Dry run only. Add --write to update data/leads.csv.");
  process.exit(0);
}

if (imported.rows.length) await writeLeads([...existing, ...imported.rows]);
console.log(`Imported ${imported.rows.length} lead(s). No lead was approved or emailed.`);
