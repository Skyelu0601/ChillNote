import fs from "node:fs/promises";
import path from "node:path";
import { offerCodesDir, partnerOfferProductId } from "../src/config.mjs";
import { readAssignmentLedger, writeAssignmentLedger } from "../src/assignment-store.mjs";
import { normalizeEmail, readLeads, writeLeads } from "../src/lead-store.mjs";
import { assignNextOfferCode, parseAppleOfferCodes } from "../src/offer-codes.mjs";

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? "" : process.argv[index + 1]?.trim() || "";
}

const kind = "partner";
const email = normalizeEmail(arg("--email"));
const creatorName = arg("--name");
if (!email || !creatorName) throw new Error("Required: --email and --name.");

const rows = await readLeads();
const lead = rows.find((row) => normalizeEmail(row.email) === email);
if (!lead) throw new Error("Creator does not match the lead record.");
if (lead.partner_status !== "joined") {
  throw new Error("Mark the creator as joined before assigning a one-year partner code.");
}

const explicitFile = arg("--codes-file");
const codesFile = explicitFile ? path.resolve(explicitFile) : path.join(offerCodesDir, `${kind}.csv`);
const productMarkerFile = `${codesFile}.product-id`;
let codesText;
try {
  const [inventory, productId] = await Promise.all([
    fs.readFile(codesFile, "utf8"),
    fs.readFile(productMarkerFile, "utf8"),
  ]);
  if (productId.trim() !== partnerOfferProductId) {
    throw new Error(
      `Refusing partner inventory: ${productMarkerFile} must contain ${partnerOfferProductId}.`,
    );
  }
  codesText = inventory;
} catch (error) {
  if (error.code === "ENOENT") {
    throw new Error(
      `Missing one-year Offer Code inventory or product marker. Expected ${codesFile} and ${productMarkerFile}.`,
    );
  }
  throw error;
}

const codes = parseAppleOfferCodes(codesText);
const ledger = await readAssignmentLedger();
const result = assignNextOfferCode(codes, ledger.assignments, {
  creator_name: creatorName,
  handle: lead.handle,
  email,
}, kind);
if (result.created) ledger.assignments.push(result.assignment);
await writeAssignmentLedger(ledger);

lead.creator_name = creatorName;
lead.partner_status = "code_assigned";
await writeLeads(rows);

const currentCodes = new Set(codes.map((item) => item.code));
const assignedForKind = ledger.assignments.filter(
  (item) => item.kind === kind && currentCodes.has(item.code),
).length;
console.log(`${result.created ? "Assigned" : "Existing assignment retained"} (${kind}) for ${creatorName} <${email}>.`);
console.log(`Codes: ${codes.length}; assigned for ${kind}: ${assignedForKind}; remaining: ${codes.length - assignedForKind}.`);
console.log("The full code and redemption URL were stored locally and were not printed.");
