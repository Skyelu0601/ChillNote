import fs from "node:fs/promises";
import { offerCodeAssignmentsPath } from "./config.mjs";

export async function readAssignmentLedger(filePath = offerCodeAssignmentsPath) {
  try {
    const ledger = JSON.parse(await fs.readFile(filePath, "utf8"));
    return {
      ...ledger,
      version: Math.max(Number(ledger.version) || 1, 2),
      assignments: Array.isArray(ledger.assignments) ? ledger.assignments : [],
    };
  } catch (error) {
    if (error.code === "ENOENT") return { version: 2, assignments: [] };
    throw error;
  }
}

export async function writeAssignmentLedger(ledger, filePath = offerCodeAssignmentsPath) {
  const temporaryPath = `${filePath}.tmp`;
  await fs.writeFile(temporaryPath, `${JSON.stringify({ ...ledger, version: 2 }, null, 2)}\n`, {
    mode: 0o600,
  });
  await fs.rename(temporaryPath, filePath);
}
