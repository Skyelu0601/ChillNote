import fs from "node:fs/promises";
import path from "node:path";
import { ApifyClient } from "apify-client";
import { stringify } from "csv-stringify/sync";
import { apifyConfig, toolRoot } from "../src/config.mjs";
import {
  buildTikTokEmailInput,
  deduplicateTikTokEmailResults,
  massTikTokEmailActor,
  parseTikTokEmailArgs,
} from "../src/tiktok-email.mjs";

const usage = `Usage:
  npm run discover:tiktok-emails -- --keyword "AI productivity" [options]

Options:
  --keyword <text>     Search keyword; repeat for multiple keywords (required)
  --domain <domain>    Email domain; repeat for multiple domains
  --location <text>   Optional location filter
  --max-emails <n>    Maximum returned emails, 1-10000 (default: 20)
  --run                Start the paid Apify Actor run
  --help               Show this help

Without --run, the command only previews the paid request.`;

let options;
try {
  options = parseTikTokEmailArgs(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  console.error(`\n${usage}`);
  process.exit(1);
}

if (options.help) {
  console.log(usage);
  process.exit(0);
}

const input = buildTikTokEmailInput(options);
const estimatedActorFee = options.maxEmails * 0.0025;

console.log(`Actor: ${massTikTokEmailActor}`);
console.log(JSON.stringify(input, null, 2));
console.log(`Maximum advertised result fee on the FREE tier: about $${estimatedActorFee.toFixed(2)}`);

if (!options.run) {
  console.log("\nPreview only. Add --run to start the paid Actor run.");
  process.exit(0);
}

const client = new ApifyClient(apifyConfig());
console.log("\nStarting Apify Actor run...");
const run = await client.actor(massTikTokEmailActor).call(input);

if (!run?.defaultDatasetId) {
  throw new Error(`Actor run ${run?.id || "unknown"} did not return a dataset.`);
}

const { items } = await client.dataset(run.defaultDatasetId).listItems();
const results = deduplicateTikTokEmailResults(items);
const timestamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
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

console.log(`Run status: ${run.status}`);
console.log(`Raw results: ${items.length}`);
console.log(`Unique emails: ${results.length}`);
console.log(`Saved JSON: ${basePath}.json`);
console.log(`Saved CSV: ${basePath}.csv`);
console.log("Results were not added to data/leads.csv and are not approved for sending.");
