import { createVerify } from "node:crypto";
import type { Express } from "express";
import express from "express";
import fetch from "node-fetch";
import { Prisma } from "@prisma/client";
import { prisma } from "./db.js";
import { marketingWinbackKinds } from "./emailMarketing.js";

type SnsEnvelope = {
  Type: string;
  MessageId: string;
  TopicArn: string;
  Message: string;
  Timestamp: string;
  SignatureVersion: string;
  Signature: string;
  SigningCertURL: string;
  Subject?: string;
  SubscribeURL?: string;
  Token?: string;
};

type SesEvent = {
  eventType?: string;
  notificationType?: string;
  mail?: {
    messageId?: string;
    timestamp?: string;
    tags?: Record<string, string[]>;
  };
  delivery?: { timestamp?: string; processingTimeMillis?: number; smtpResponse?: string };
  bounce?: { timestamp?: string; bounceType?: string; bounceSubType?: string };
  complaint?: { timestamp?: string; complaintFeedbackType?: string; complaintSubType?: string };
  reject?: { reason?: string };
  deliveryDelay?: { timestamp?: string; delayType?: string };
};

export type ParsedSesEvent = {
  deliveryId: string | null;
  providerMessageId: string;
  eventType: string;
  providerStatus: string;
  eventTimestamp: Date;
  details: Prisma.InputJsonValue;
  suppressReason: string | null;
};

const certCache = new Map<string, { pem: string; expiresAt: number }>();

function topicRegion(topicArn: string): string | null {
  const parts = topicArn.split(":");
  return parts.length >= 6 && parts[0] === "arn" && parts[2] === "sns" ? parts[3] : null;
}

export function snsURLAllowed(rawURL: string, topicArn: string, certificate: boolean): boolean {
  try {
    const url = new URL(rawURL);
    const region = topicRegion(topicArn);
    if (!region || url.protocol !== "https:" || url.username || url.password || url.port) return false;
    if (url.hostname !== `sns.${region}.amazonaws.com`) return false;
    return certificate
      ? /^\/SimpleNotificationService-[A-Za-z0-9_-]+\.pem$/.test(url.pathname)
      : url.pathname === "/" && url.searchParams.get("Action") === "ConfirmSubscription"
        && url.searchParams.get("TopicArn") === topicArn;
  } catch {
    return false;
  }
}

export function snsStringToSign(message: SnsEnvelope): string | null {
  const fields = message.Type === "Notification"
    ? ["Message", "MessageId", ...(message.Subject ? ["Subject"] : []), "Timestamp", "TopicArn", "Type"]
    : message.Type === "SubscriptionConfirmation" || message.Type === "UnsubscribeConfirmation"
      ? ["Message", "MessageId", "SubscribeURL", "Timestamp", "Token", "TopicArn", "Type"]
      : [];
  if (fields.length === 0) return null;
  let result = "";
  for (const field of fields) {
    const value = message[field as keyof SnsEnvelope];
    if (typeof value !== "string" || !value) return null;
    result += `${field}\n${value}\n`;
  }
  return result;
}

async function signingCertificate(message: SnsEnvelope): Promise<string> {
  if (!snsURLAllowed(message.SigningCertURL, message.TopicArn, true)) {
    throw new Error("Untrusted SNS signing certificate URL");
  }
  const cached = certCache.get(message.SigningCertURL);
  if (cached && cached.expiresAt > Date.now()) return cached.pem;
  const response = await fetch(message.SigningCertURL, { signal: AbortSignal.timeout(5_000) });
  if (!response.ok) throw new Error(`Unable to fetch SNS certificate (${response.status})`);
  const pem = await response.text();
  if (pem.length > 16_384 || !pem.includes("BEGIN CERTIFICATE")) {
    throw new Error("Invalid SNS signing certificate");
  }
  certCache.set(message.SigningCertURL, { pem, expiresAt: Date.now() + 60 * 60_000 });
  return pem;
}

async function verifySnsMessage(message: SnsEnvelope, expectedTopicArn: string): Promise<boolean> {
  if (message.TopicArn !== expectedTopicArn || !["1", "2"].includes(message.SignatureVersion)) return false;
  const stringToSign = snsStringToSign(message);
  if (!stringToSign || typeof message.Signature !== "string") return false;
  const pem = await signingCertificate(message);
  const verifier = createVerify(message.SignatureVersion === "2" ? "RSA-SHA256" : "RSA-SHA1");
  verifier.update(stringToSign, "utf8");
  verifier.end();
  return verifier.verify(pem, message.Signature, "base64");
}

function validDate(value: unknown, fallback: Date): Date {
  if (typeof value !== "string") return fallback;
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : fallback;
}

export function parseSesEvent(raw: unknown, fallback = new Date()): ParsedSesEvent | null {
  if (!raw || typeof raw !== "object") return null;
  const event = raw as SesEvent;
  const eventType = (event.eventType ?? event.notificationType ?? "").trim();
  const providerMessageId = event.mail?.messageId?.trim() ?? "";
  if (!eventType || !providerMessageId) return null;
  const normalized = eventType.toLowerCase().replace(/\s+/g, "_");
  const statusByType: Record<string, string> = {
    send: "accepted",
    delivery: "delivered",
    bounce: "bounced",
    complaint: "complained",
    reject: "rejected",
    deliverydelay: "delayed",
    delivery_delay: "delayed",
    rendering_failure: "rendering_failed"
  };
  const providerStatus = statusByType[normalized];
  if (!providerStatus) return null;
  const eventTimestamp = validDate(
    event.delivery?.timestamp
      ?? event.bounce?.timestamp
      ?? event.complaint?.timestamp
      ?? event.deliveryDelay?.timestamp
      ?? event.mail?.timestamp,
    fallback
  );
  const permanentBounce = providerStatus === "bounced" && event.bounce?.bounceType === "Permanent";
  const details: Prisma.InputJsonValue = {
    ...(event.delivery?.processingTimeMillis !== undefined
      ? { processingTimeMillis: event.delivery.processingTimeMillis }
      : {}),
    ...(event.delivery?.smtpResponse ? { smtpResponse: event.delivery.smtpResponse.slice(0, 500) } : {}),
    ...(event.bounce?.bounceType ? { bounceType: event.bounce.bounceType } : {}),
    ...(event.bounce?.bounceSubType ? { bounceSubType: event.bounce.bounceSubType } : {}),
    ...(event.complaint?.complaintFeedbackType
      ? { complaintFeedbackType: event.complaint.complaintFeedbackType }
      : {}),
    ...(event.complaint?.complaintSubType ? { complaintSubType: event.complaint.complaintSubType } : {}),
    ...(event.reject?.reason ? { rejectReason: event.reject.reason.slice(0, 500) } : {}),
    ...(event.deliveryDelay?.delayType ? { delayType: event.deliveryDelay.delayType } : {})
  };
  return {
    deliveryId: event.mail?.tags?.delivery_id?.[0] ?? null,
    providerMessageId,
    eventType,
    providerStatus,
    eventTimestamp,
    details,
    suppressReason: providerStatus === "complained"
      ? "ses_complaint"
      : permanentBounce ? "ses_permanent_bounce" : null
  };
}

const statusPriority: Record<string, number> = {
  accepted: 1,
  delayed: 2,
  delivered: 3,
  rendering_failed: 4,
  rejected: 5,
  bounced: 6,
  complained: 7
};

export function preferredProviderStatus(current: string | null, incoming: string): string {
  return (statusPriority[incoming] ?? 0) >= (statusPriority[current ?? ""] ?? 0) ? incoming : current!;
}

async function recordSesEvent(snsMessageId: string, parsed: ParsedSesEvent): Promise<boolean> {
  const delivery = await prisma.emailDelivery.findFirst({
    where: parsed.deliveryId
      ? { OR: [{ id: parsed.deliveryId }, { providerMessageId: parsed.providerMessageId }] }
      : { providerMessageId: parsed.providerMessageId },
    select: { id: true, userId: true, providerStatus: true, providerEventAt: true }
  });
  if (!delivery) return false;

  await prisma.$transaction(async (tx) => {
    await tx.emailEvent.upsert({
      where: { snsMessageId_eventType: { snsMessageId, eventType: parsed.eventType } },
      create: {
        deliveryId: delivery.id,
        providerMessageId: parsed.providerMessageId,
        snsMessageId,
        eventType: parsed.eventType,
        eventTimestamp: parsed.eventTimestamp,
        details: parsed.details
      },
      update: {}
    });
    const providerStatus = preferredProviderStatus(delivery.providerStatus, parsed.providerStatus);
    const providerEventAt = !delivery.providerEventAt || parsed.eventTimestamp >= delivery.providerEventAt
      ? parsed.eventTimestamp
      : delivery.providerEventAt;
    await tx.emailDelivery.update({
      where: { id: delivery.id },
      data: {
        providerStatus,
        providerEventAt,
        deliveredAt: parsed.providerStatus === "delivered" ? parsed.eventTimestamp : undefined,
        bouncedAt: parsed.providerStatus === "bounced" ? parsed.eventTimestamp : undefined,
        complainedAt: parsed.providerStatus === "complained" ? parsed.eventTimestamp : undefined
      }
    });
    if (parsed.suppressReason) {
      await tx.emailPreference.upsert({
        where: { userId: delivery.userId },
        create: {
          userId: delivery.userId,
          marketingStatus: "unsubscribed",
          marketingUnsubscribedAt: parsed.eventTimestamp,
          serviceSuppressedAt: parsed.eventTimestamp,
          suppressionReason: parsed.suppressReason
        },
        update: {
          marketingStatus: "unsubscribed",
          marketingUnsubscribedAt: parsed.eventTimestamp,
          serviceSuppressedAt: parsed.eventTimestamp,
          suppressionReason: parsed.suppressReason
        }
      });
      await tx.emailDelivery.updateMany({
        where: {
          userId: delivery.userId,
          kind: { in: marketingWinbackKinds() },
          status: { in: ["scheduled", "processing"] }
        },
        data: { status: "cancelled", lastError: parsed.suppressReason }
      });
    }
  });
  return true;
}

function isSnsEnvelope(value: unknown): value is SnsEnvelope {
  if (!value || typeof value !== "object") return false;
  const row = value as Record<string, unknown>;
  return ["Type", "MessageId", "TopicArn", "Message", "Timestamp", "SignatureVersion", "Signature", "SigningCertURL"]
    .every((key) => typeof row[key] === "string" && row[key]);
}

export function registerSesEventRoute(app: Express): void {
  app.post("/webhooks/ses", express.text({ type: "*/*", limit: "256kb" }), async (req, res) => {
    const expectedTopicArn = process.env.SES_EVENT_TOPIC_ARN?.trim() ?? "";
    if (!expectedTopicArn) {
      res.status(503).json({ error: "SES event tracking is not configured" });
      return;
    }
    let envelope: unknown;
    try {
      envelope = JSON.parse(typeof req.body === "string" ? req.body : "");
    } catch {
      res.status(400).json({ error: "Invalid SNS message" });
      return;
    }
    if (!isSnsEnvelope(envelope)) {
      res.status(400).json({ error: "Invalid SNS envelope" });
      return;
    }
    try {
      if (!await verifySnsMessage(envelope, expectedTopicArn)) {
        res.status(401).json({ error: "Invalid SNS signature" });
        return;
      }
      if (envelope.Type === "SubscriptionConfirmation") {
        if (!envelope.SubscribeURL || !snsURLAllowed(envelope.SubscribeURL, expectedTopicArn, false)) {
          res.status(400).json({ error: "Invalid SNS subscription URL" });
          return;
        }
        const confirmation = await fetch(envelope.SubscribeURL, { signal: AbortSignal.timeout(5_000) });
        if (!confirmation.ok) throw new Error(`SNS confirmation failed (${confirmation.status})`);
        res.json({ received: true, confirmed: true });
        return;
      }
      if (envelope.Type !== "Notification") {
        res.json({ received: true, ignored: true });
        return;
      }
      const parsed = parseSesEvent(JSON.parse(envelope.Message));
      if (!parsed) {
        res.json({ received: true, ignored: true });
        return;
      }
      const recorded = await recordSesEvent(envelope.MessageId, parsed);
      res.json({ received: true, recorded });
    } catch (error) {
      console.error("SES event webhook failed:", error instanceof Error ? error.message : "UnknownError");
      res.status(500).json({ error: "Unable to process SES event" });
    }
  });
}
