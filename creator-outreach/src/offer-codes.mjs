import { parse } from "csv-parse/sync";

export function parseAppleOfferCodes(csvText) {
  const records = parse(csvText, {
    columns: false,
    skip_empty_lines: true,
    trim: true,
  });
  const seenCodes = new Set();
  const seenUrls = new Set();

  return records.map((record, index) => {
    if (record.length !== 2) throw new Error(`Offer code row ${index + 1} needs two columns.`);
    const [code, redemptionUrl] = record;
    const url = new URL(redemptionUrl);
    if (url.hostname !== "apps.apple.com" || url.pathname !== "/redeem") {
      throw new Error(`Offer code row ${index + 1} has an unexpected redemption URL.`);
    }
    if (url.searchParams.get("code") !== code) {
      throw new Error(`Offer code row ${index + 1} does not match its redemption URL.`);
    }
    if (seenCodes.has(code) || seenUrls.has(redemptionUrl)) {
      throw new Error(`Duplicate Apple offer code at row ${index + 1}.`);
    }
    seenCodes.add(code);
    seenUrls.add(redemptionUrl);
    return { code, redemption_url: redemptionUrl };
  });
}

export function assignmentKind(assignment) {
  return assignment.kind || "legacy";
}

export function findOfferCodeAssignment(assignments, email, kind) {
  const normalizedEmail = email.trim().toLowerCase();
  return assignments.find(
    (item) => item.email.toLowerCase() === normalizedEmail && assignmentKind(item) === kind,
  );
}

export function assignNextOfferCode(codes, assignments, creator, kind = "partner") {
  if (kind !== "partner") throw new Error("New assignments must use the one-year partner offer.");
  const email = creator.email.trim().toLowerCase();
  const existing = findOfferCodeAssignment(assignments, email, kind);
  if (existing) return { assignment: existing, created: false };

  const usedCodes = new Set(assignments.map((item) => item.code));
  const available = codes.find((item) => !usedCodes.has(item.code));
  if (!available) throw new Error("No unassigned Apple offer codes remain.");

  return {
    created: true,
    assignment: {
      creator_name: creator.creator_name,
      handle: creator.handle,
      email,
      kind,
      code: available.code,
      redemption_url: available.redemption_url,
      status: "assigned",
      assigned_at: new Date().toISOString(),
      sent_at: "",
      redeemed: "unknown",
    },
  };
}
