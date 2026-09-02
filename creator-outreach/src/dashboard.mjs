export function parseKeywords(value) {
  const items = Array.isArray(value) ? value : String(value || "").split(/[\n,]/);
  return [...new Set(items.map((item) => item.trim()).filter(Boolean))];
}

export function isDirectTikTokSource(value) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase().replace(/^www\./, "");
    return host === "tiktok.com" && url.pathname.startsWith("/@");
  } catch {
    return false;
  }
}

export function isPendingSendable(row, allowMxOnly = true) {
  if (row.status !== "pending" || !isDirectTikTokSource(row.email_source)) return false;
  if (["valid", "accepted"].includes(row.email_status)) return true;
  return allowMxOnly && row.email_status === "mx_only";
}

export function summarizeLeads(rows) {
  const count = (predicate) => rows.filter(predicate).length;
  return {
    total: rows.length,
    sent: count((row) => row.status === "sent"),
    pending: count((row) => row.status === "pending"),
    bounced: count((row) => row.status === "bounced"),
    failed: count((row) => row.status === "failed"),
    blocked: count((row) => row.status === "blocked"),
    replied: count((row) => row.reply_status === "replied"),
    registrationReported: count((row) => row.partner_status === "verification_pending"),
    partnersJoined: count((row) => ["joined", "code_assigned", "code_sent"].includes(row.partner_status)),
    eligible: count((row) => isPendingSendable(row, true)),
    approved: count((row) => row.status === "pending" && row.approved === "yes"),
  };
}

export function publicLead(row, assignments = []) {
  const partnerAssignment = assignments.find((assignment) => assignment.kind === "partner") || null;
  return {
    id: row.id,
    creator_name: row.creator_name,
    handle: row.handle,
    email: row.email,
    email_source: row.email_source,
    source_keyword: row.source_keyword,
    personalization: row.personalization,
    email_status: row.email_status,
    approved: row.approved,
    status: row.status,
    sent_at: row.sent_at,
    bounce_reason: row.bounce_reason,
    reply_status: row.reply_status,
    reply_intent: row.reply_intent,
    last_reply_at: row.last_reply_at,
    partner_status: row.partner_status,
    partner_joined_at: row.partner_joined_at,
    affiliate_link: row.affiliate_link,
    partner: partnerAssignment
      ? {
          status: partnerAssignment.status,
          sent_at: partnerAssignment.sent_at,
          redeemed: partnerAssignment.redeemed || "unknown",
        }
      : null,
  };
}
