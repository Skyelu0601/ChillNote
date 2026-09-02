function replyText(parsed) {
  const body = String(parsed.text || "");
  const freshBody = body.split(
    /\n\s*(?:On .+wrote:|From:\s|-----Original Message-----|_{5,}|>)/i,
    1,
  )[0];
  return [freshBody, parsed.subject].filter(Boolean).join("\n").trim();
}

export function classifyReplyIntent(parsed, lead = {}) {
  const subject = String(parsed.subject || "");
  const text = replyText(parsed);
  const normalized = text.toLowerCase();

  if (
    /automatic reply|auto.?reply|out of office|away from the office|vacation reply/i.test(subject) ||
    /this is an automated (?:reply|response)|i am currently out of (?:the )?office/i.test(normalized)
  ) {
    return "auto_reply";
  }

  if (
    /^(?:\s)*(?:no|no thanks|not interested|stop|unsubscribe|remove me)(?:[\s,.!]|$)/i.test(text)
  ) {
    return "opt_out";
  }

  if (
    /^\s*done\b/i.test(text) ||
    /\b(?:registered|joined|signed\s*up|completed\s+(?:the\s+)?(?:signup|registration))\b/i.test(text)
  ) {
    return "affiliate_verification_pending";
  }

  return "manual_review";
}

export function applyReplyIntent(row, intent, receivedAt = new Date().toISOString()) {
  row.reply_status = ["auto_reply", "opt_out"].includes(intent) ? intent : "replied";
  row.reply_intent = intent;
  row.last_reply_at = receivedAt;

  if (intent === "affiliate_verification_pending") {
    row.partner_status = "verification_pending";
  } else if (intent === "opt_out") {
    row.approved = "no";
    row.status = "blocked";
    row.partner_status = "declined";
  }

  return row;
}
