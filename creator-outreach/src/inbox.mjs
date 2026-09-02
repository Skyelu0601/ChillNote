import fs from "node:fs/promises";
import { ImapFlow } from "imapflow";
import { simpleParser } from "mailparser";
import { mailConfig, syncStatePath } from "./config.mjs";
import { normalizeEmail } from "./lead-store.mjs";

export function createImapClient() {
  const config = mailConfig();
  return new ImapFlow({
    host: config.imap.host,
    port: config.imap.port,
    secure: config.imap.secure,
    auth: {
      user: config.user,
      pass: config.password,
    },
    logger: false,
  });
}

export function isStaleDeliveryNotice(messageDate, sentAt) {
  if (!messageDate || !sentAt) return false;
  const noticeTime = new Date(messageDate).getTime();
  const sentTime = new Date(sentAt).getTime();
  if (!Number.isFinite(noticeTime) || !Number.isFinite(sentTime)) return false;
  // Mail headers are often rounded to whole seconds while sent_at keeps
  // milliseconds. Treat only clearly older notices as stale.
  return noticeTime < sentTime - 60_000;
}

export async function verifyImap() {
  const client = createImapClient();
  await client.connect();
  await client.logout();
}

export function classifyIncomingMessage(parsed, leads) {
  const subject = parsed.subject || "";
  const text = [parsed.text, parsed.html, subject].filter(Boolean).join("\n");
  const normalizedText = text.toLowerCase();
  const sender = normalizeEmail(parsed.from?.value?.[0]?.address || "");
  const isBounce =
    subject.includes("退信") ||
    normalizedText.includes("退信通知") ||
    sender === "no-reply@mailsupport.aliyun.com" ||
    /mail delivery|delivery status notification|undeliver/i.test(subject);

  if (isBounce) {
    const mentionedEmails = new Set(
      (text.match(/[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}/gi) || [])
        .map((value) => normalizeEmail(value)),
    );
    const lead = leads.find((candidate) => mentionedEmails.has(normalizeEmail(candidate.email)));
    if (!lead) return { type: "unmatched_bounce" };

    if (/ESO_LOCAL_SPAM|local spam engine/i.test(text)) {
      return {
        type: "outbound_blocked",
        leadId: lead.id,
        reason: "Alibaba outbound spam filter blocked the message before delivery",
      };
    }

    let reason = "mailbox rejected the message";
    if (/mx|邮件解析|域名不存在/i.test(text)) reason = "recipient domain has no MX record";
    else if (/mailbox.*full|quota|邮箱.*满/i.test(text)) reason = "recipient mailbox is full";
    else if (/user unknown|recipient.*not found|does not exist|NoSuchUser|账号不存在|收件人不存在/i.test(text)) {
      reason = "recipient mailbox does not exist";
    }
    return { type: "bounce", leadId: lead.id, reason };
  }

  const inReplyTo = parsed.inReplyTo || "";
  const lead =
    leads.find((candidate) => candidate.message_id && inReplyTo.includes(candidate.message_id)) ||
    leads.find((candidate) => normalizeEmail(candidate.email) === sender);

  if (lead) return { type: "reply", leadId: lead.id, sender };
  return { type: "unmatched" };
}

export async function readSyncState() {
  try {
    return JSON.parse(await fs.readFile(syncStatePath, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return { processedMessageIds: [], lastSyncAt: null };
    throw error;
  }
}

export async function writeSyncState(state) {
  await fs.writeFile(syncStatePath, `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

export async function fetchRecentMessages({ since, processedMessageIds = [] }) {
  const client = createImapClient();
  const processed = new Set(processedMessageIds);
  const messages = [];
  await client.connect();
  const lock = await client.getMailboxLock("INBOX");

  try {
    const uids = await client.search({ since }, { uid: true });
    if (!uids.length) return messages;

    for await (const message of client.fetch(
      uids,
      { uid: true, envelope: true, source: true },
      { uid: true },
    )) {
      const parsed = await simpleParser(message.source);
      const messageId = parsed.messageId || `uid:${message.uid}`;
      if (processed.has(messageId)) continue;
      messages.push({ uid: message.uid, messageId, parsed });
    }
    return messages;
  } finally {
    lock.release();
    await client.logout();
  }
}
