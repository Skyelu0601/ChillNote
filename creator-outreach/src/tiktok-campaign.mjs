import { parseTikTokEmailArgs } from "./tiktok-email.mjs";

function numericValue(args, index, flag) {
  const value = Number(args[index + 1]);
  if (!Number.isFinite(value)) throw new Error(`${flag} requires a number.`);
  return value;
}

export function parseTikTokCampaignArgs(args) {
  const actorArgs = [];
  const workflow = {
    send: false,
    allowMxOnly: false,
    delayMin: 60,
    delayMax: 120,
  };

  for (let index = 0; index < args.length; index += 1) {
    const flag = args[index];
    if (flag === "--send") {
      workflow.send = true;
    } else if (flag === "--allow-mx-only") {
      workflow.allowMxOnly = true;
    } else if (flag === "--delay-min") {
      workflow.delayMin = numericValue(args, index, flag);
      index += 1;
    } else if (flag === "--delay-max") {
      workflow.delayMax = numericValue(args, index, flag);
      index += 1;
    } else {
      actorArgs.push(flag);
    }
  }

  const actor = parseTikTokEmailArgs(actorArgs);
  if (actor.help) return { actor, ...workflow };
  if (workflow.send && !actor.run) {
    throw new Error("--send requires --run because there is no new campaign to send.");
  }
  if (workflow.send && actor.maxEmails > 105) {
    throw new Error("A live keyword campaign is capped at 105 requested results.");
  }
  if (workflow.delayMin < 0 || workflow.delayMax < workflow.delayMin) {
    throw new Error("Invalid delay range.");
  }
  return { actor, ...workflow };
}

export function isCampaignSendable(row, allowMxOnly = false) {
  if (row.status !== "pending") return false;
  if (["valid", "accepted"].includes(row.email_status)) return true;
  return allowMxOnly && row.email_status === "mx_only";
}
