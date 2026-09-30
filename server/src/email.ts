import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";
import type { Express, RequestHandler } from "express";
import express from "express";
import { z } from "zod";
import { prisma } from "./db.js";
import {
  isLifecycleEmailKind,
  isTrialEndingKind,
  lifecycleEmailKindsToCancel,
  lifecycleEmailSchedules
} from "./emailLifecycle.js";
import {
  isMarketingWinbackKind,
  marketingWinbackKinds,
  nextMarketingWinbackSchedule
} from "./emailMarketing.js";
import { renderBillingIssueEmail, renderCancelledTrialEmail, renderTrialEndingEmail } from "./emailTemplates.js";
import { renderMarketingWinbackEmail } from "./marketingEmailTemplates.js";
import {
  categoryAllowsEmail,
  marketingEmailsEnabled,
  parseUnsubscribeCategories,
  renderEmailChoicesPage,
  type UnsubscribeCategory
} from "./emailPreferences.js";
import type { RevenueCatWebhook } from "./revenueCat.js";
import { subscriptionURL } from "./subscriptionLinks.js";
import { emailAppOpenURL, registerEmailAppOpenRoute } from "./emailAppLink.js";
import { upsertUser } from "./store.js";
import { supabaseAdmin } from "./supabase.js";

type EmailDeliveryRow = {
  id: string;
  userId: string;
  kind: string;
  expectedExpiresAt: Date | null;
  activityAnchorAt: Date | null;
  attempts: number;
};

const EMAIL_ENABLED = process.env.EMAIL_ENABLED === "true";
const EMAIL_MARKETING_ENABLED = process.env.EMAIL_MARKETING_ENABLED === "true";
const SES_REGION = process.env.SES_REGION?.trim() || process.env.AWS_REGION?.trim() || "";
const SES_FROM_EMAIL = process.env.SES_FROM_EMAIL?.trim() || "";
const SES_MARKETING_FROM_EMAIL = process.env.SES_MARKETING_FROM_EMAIL?.trim()
  || "ChillScript <hello@chillnoteai.com>";
const SES_REPLY_TO_EMAIL = process.env.SES_REPLY_TO_EMAIL?.trim() || "support@chillnoteai.com";
const SES_CONFIGURATION_SET = process.env.SES_CONFIGURATION_SET?.trim() || "";
const EMAIL_POLL_MS = Number(process.env.EMAIL_POLL_MS ?? 60_000);
const EMAIL_MARKETING_SCAN_MS = Number(process.env.EMAIL_MARKETING_SCAN_MS ?? 6 * 60 * 60_000);
const EMAIL_MARKETING_DAILY_LIMIT = Math.max(1, Number(process.env.EMAIL_MARKETING_DAILY_LIMIT ?? 50_000));
const EMAIL_MARKETING_HOLDOUT_PERCENT = Math.min(
  50,
  Math.max(0, Number(process.env.EMAIL_MARKETING_HOLDOUT_PERCENT ?? 10))
);
const EMAIL_UNSUBSCRIBE_SECRET = process.env.EMAIL_UNSUBSCRIBE_SECRET?.trim() || "";
const EMAIL_PUBLIC_BASE_URL = (process.env.EMAIL_PUBLIC_BASE_URL?.trim() || "https://api.chillnoteai.com")
  .replace(/\/$/, "");
const EMAIL_MARKETING_CTA_URL = emailAppOpenURL(EMAIL_PUBLIC_BASE_URL);
const EMAIL_MARKETING_POSTAL_ADDRESS = process.env.EMAIL_MARKETING_POSTAL_ADDRESS?.trim() || "";

let workerTimer: NodeJS.Timeout | null = null;
let marketingTimer: NodeJS.Timeout | null = null;
let workerRunning = false;
let marketingSchedulerRunning = false;
let sesClient: SESv2Client | null = null;

function configured(): boolean {
  return EMAIL_ENABLED && Boolean(SES_REGION && SES_FROM_EMAIL);
}

function marketingConfigured(): boolean {
  return configured()
    && EMAIL_MARKETING_ENABLED
    && Boolean(SES_MARKETING_FROM_EMAIL && EMAIL_UNSUBSCRIBE_SECRET && EMAIL_MARKETING_POSTAL_ADDRESS);
}

function isMarketingHoldout(userId: string): boolean {
  if (EMAIL_MARKETING_HOLDOUT_PERCENT <= 0) return false;
  const bucket = createHash("sha256").update(userId).digest().readUInt32BE(0) / 0x1_0000_0000 * 100;
  return bucket < EMAIL_MARKETING_HOLDOUT_PERCENT;
}

function client(): SESv2Client {
  sesClient ??= new SESv2Client({ region: SES_REGION, maxAttempts: 3 });
  return sesClient;
}

function safeErrorMessage(error: unknown): string {
  return error instanceof Error ? `${error.name}:${error.message}` : "UnknownError";
}

function sameInstant(left: Date | null, right: Date | null, toleranceMs = 5 * 60_000): boolean {
  return Boolean(left && right && Math.abs(left.getTime() - right.getTime()) <= toleranceMs);
}


export async function handleRevenueCatEmailLifecycle(
  event: RevenueCatWebhook["event"],
  userIds: string[],
  now = new Date()
): Promise<void> {
  if (userIds.length === 0) return;

  const billingIssueDetected = event.type === "BILLING_ISSUE"
    || event.type === "CANCELLATION" && event.cancel_reason === "BILLING_ERROR";
  // Expiration can happen before the store finishes billing retries.
  const billingIssueCleared = event.type === "RENEWAL" || event.type === "INITIAL_PURCHASE";
  const eventAt = new Date(event.event_timestamp_ms);
  if (billingIssueDetected) {
    // Webhooks can arrive out of order. Do not revive an issue after a later payment succeeded.
    const newerPayment = await prisma.revenueCatWebhookEvent.findFirst({
      where: {
        appUserId: { in: userIds },
        type: { in: ["RENEWAL", "INITIAL_PURCHASE"] },
        eventTimestampAt: { gte: eventAt }
      },
      select: { id: true }
    });
    if (newerPayment) return;
  }
  if (billingIssueDetected || billingIssueCleared) {
    for (const userId of userIds) {
      await prisma.emailPreference.upsert({
        where: { userId },
        create: { userId },
        update: {}
      });
      await prisma.emailPreference.updateMany({
        where: {
          userId,
          OR: [{ billingIssueAt: null }, { billingIssueAt: { lte: eventAt } }]
        },
        data: { billingIssueAt: billingIssueDetected ? eventAt : null }
      });
    }
  }
  if (billingIssueDetected) {
    await prisma.emailDelivery.updateMany({
      where: {
        userId: { in: userIds },
        kind: { in: marketingWinbackKinds() },
        status: { in: ["scheduled", "processing"] }
      },
      data: { status: "cancelled", lastError: "billing_issue_detected" }
    });
  }

  const kindsToCancel = lifecycleEmailKindsToCancel(event);
  if (kindsToCancel.length > 0) {
    await prisma.emailDelivery.updateMany({
      where: {
        userId: { in: userIds },
        kind: { in: kindsToCancel },
        status: { in: ["scheduled", "processing"] }
      },
      data: { status: "cancelled", lastError: `revenuecat_${event.type.toLowerCase()}` }
    });
  }

  const schedules = lifecycleEmailSchedules(event, now);
  if (schedules.length === 0) return;
  const preferences = await prisma.emailPreference.findMany({
    where: { userId: { in: userIds } },
    select: { userId: true, marketingStatus: true, subscriptionBillingEmailsEnabled: true }
  });
  const preferencesByUser = new Map(preferences.map((preference) => [preference.userId, preference]));
  const entitlements = await prisma.revenueCatEntitlement.findMany({
    where: { userId: { in: userIds }, isActive: true },
    select: { userId: true, expiresAt: true }
  });

  for (const schedule of schedules) {
    const owners = schedule.kind === "billing_issue"
      ? userIds.map((userId) => ({ userId }))
      : entitlements
        .filter((row) => sameInstant(row.expiresAt, schedule.expectedExpiresAt))
        .map((row) => ({ userId: row.userId }));
    for (const owner of owners) {
      if (!categoryAllowsEmail(schedule.kind, preferencesByUser.get(owner.userId) ?? null)) continue;
      const expiryKey = schedule.expectedExpiresAt.toISOString();
      await prisma.emailDelivery.upsert({
        where: { dedupeKey: `${schedule.kind}:${owner.userId}:${expiryKey}` },
        create: {
          userId: owner.userId,
          kind: schedule.kind,
          dedupeKey: `${schedule.kind}:${owner.userId}:${expiryKey}`,
          scheduledAt: schedule.scheduledAt,
          expectedExpiresAt: schedule.expectedExpiresAt
        },
        update: {}
      });
    }
  }
}

function newestDate(values: Array<Date | null | undefined>): Date | null {
  const timestamps = values.flatMap((value) => value ? [value.getTime()] : []);
  return timestamps.length ? new Date(Math.max(...timestamps)) : null;
}

async function latestMeaningfulActivityAt(userId: string): Promise<Date | null> {
  const [note, linkImport, conversation] = await Promise.all([
    prisma.note.findFirst({
      where: { userId, serverDeletedAt: null, isChilloDraft: false },
      orderBy: { serverUpdatedAt: "desc" },
      select: { serverUpdatedAt: true }
    }),
    prisma.linkImportJob.findFirst({
      where: { userId },
      orderBy: { updatedAt: "desc" },
      select: { updatedAt: true }
    }),
    prisma.chilloConversation.findFirst({
      where: { userId },
      orderBy: { updatedAt: "desc" },
      select: { updatedAt: true }
    })
  ]);
  return newestDate([note?.serverUpdatedAt, linkImport?.updatedAt, conversation?.updatedAt]);
}

export async function runMarketingWinbackScheduler(now = new Date()): Promise<void> {
  if (!marketingConfigured() || marketingSchedulerRunning) return;
  marketingSchedulerRunning = true;
  try {
    const users = await prisma.user.findMany({
      where: {
        OR: [
          { emailPreference: { is: null } },
          { emailPreference: { is: {
            marketingStatus: { not: "unsubscribed" },
            serviceSuppressedAt: null,
            billingIssueAt: null
          } } }
        ]
      },
      select: {
        id: true,
        notes: {
          where: { serverDeletedAt: null, isChilloDraft: false },
          orderBy: { serverUpdatedAt: "desc" },
          take: 1,
          select: { serverUpdatedAt: true }
        },
        linkImportJobs: {
          orderBy: { updatedAt: "desc" },
          take: 1,
          select: { updatedAt: true }
        },
        chilloConversations: {
          orderBy: { updatedAt: "desc" },
          take: 1,
          select: { updatedAt: true }
        }
      }
    });
    if (users.length === 0) return;

    const userIds = users.map((user) => user.id);
    const deliveries = await prisma.emailDelivery.findMany({
      where: { userId: { in: userIds } },
      select: {
        id: true,
        userId: true,
        kind: true,
        status: true,
        sentAt: true,
        activityAnchorAt: true
      }
    });
    const deliveriesByUser = new Map<string, typeof deliveries>();
    for (const delivery of deliveries) {
      const rows = deliveriesByUser.get(delivery.userId) ?? [];
      rows.push(delivery);
      deliveriesByUser.set(delivery.userId, rows);
    }

    const recentServiceCutoff = new Date(now.getTime() - 72 * 60 * 60_000);
    const obsoleteDeliveryIds: string[] = [];
    const schedules: Array<{
      userId: string;
      kind: ReturnType<typeof marketingWinbackKinds>[number];
      scheduledAt: Date;
      activityAnchorAt: Date;
    }> = [];

    for (const user of users) {
      if (isMarketingHoldout(user.id)) continue;
      const lastActivityAt = newestDate([
        user.notes[0]?.serverUpdatedAt,
        user.linkImportJobs[0]?.updatedAt,
        user.chilloConversations[0]?.updatedAt
      ]);
      if (!lastActivityAt) continue;

      const userDeliveries = deliveriesByUser.get(user.id) ?? [];
      const recentCompletedSequence = userDeliveries.some((delivery) =>
        delivery.kind === "marketing_winback_3"
        && delivery.status === "sent"
        && delivery.sentAt
        && delivery.sentAt >= new Date(now.getTime() - 60 * 24 * 60 * 60_000)
      );
      if (recentCompletedSequence) continue;
      for (const delivery of userDeliveries) {
        if (isMarketingWinbackKind(delivery.kind)
          && delivery.activityAnchorAt
          && delivery.activityAnchorAt < lastActivityAt
          && (delivery.status === "scheduled" || delivery.status === "processing")) {
          obsoleteDeliveryIds.push(delivery.id);
        }
      }
      const hasRecentServiceEmail = userDeliveries.some((delivery) =>
        !isMarketingWinbackKind(delivery.kind)
        && delivery.status === "sent"
        && delivery.sentAt
        && delivery.sentAt >= recentServiceCutoff
      );
      if (hasRecentServiceEmail) continue;

      const currentCycle = userDeliveries.flatMap((delivery) =>
        isMarketingWinbackKind(delivery.kind)
          && sameInstant(delivery.activityAnchorAt, lastActivityAt, 1_000)
          ? [{ kind: delivery.kind, status: delivery.status, sentAt: delivery.sentAt }]
          : []
      );
      const schedule = nextMarketingWinbackSchedule({ lastActivityAt, deliveries: currentCycle, now });
      if (schedule) {
        schedules.push({
          userId: user.id,
          kind: schedule.kind,
          scheduledAt: schedule.scheduledAt,
          activityAnchorAt: lastActivityAt
        });
      }
    }

    if (obsoleteDeliveryIds.length > 0) {
      await prisma.emailDelivery.updateMany({
        where: { id: { in: obsoleteDeliveryIds }, status: { in: ["scheduled", "processing"] } },
        data: { status: "cancelled", lastError: "user_became_active" }
      });
    }
    const sentInLast24Hours = deliveries.filter((delivery) =>
      isMarketingWinbackKind(delivery.kind)
      && delivery.status === "sent"
      && delivery.sentAt
      && delivery.sentAt >= new Date(now.getTime() - 24 * 60 * 60_000)
    ).length;
    const alreadyQueued = deliveries.filter((delivery) =>
      isMarketingWinbackKind(delivery.kind)
      && (delivery.status === "scheduled" || delivery.status === "processing")
    ).length;
    const availableSlots = Math.max(0, EMAIL_MARKETING_DAILY_LIMIT - sentInLast24Hours - alreadyQueued);
    const selectedSchedules = schedules
      .sort((left, right) => right.activityAnchorAt.getTime() - left.activityAnchorAt.getTime())
      .slice(0, availableSlots);
    for (const schedule of selectedSchedules) {
      const anchorKey = schedule.activityAnchorAt.toISOString();
      const dedupeKey = `${schedule.kind}:${schedule.userId}:${anchorKey}`;
      await prisma.emailDelivery.upsert({
        where: { dedupeKey },
        create: {
          userId: schedule.userId,
          kind: schedule.kind,
          dedupeKey,
          scheduledAt: schedule.scheduledAt,
          activityAnchorAt: schedule.activityAnchorAt
        },
        update: {}
      });
    }
  } catch (error) {
    console.error("Marketing win-back scheduler failed:", safeErrorMessage(error));
  } finally {
    marketingSchedulerRunning = false;
  }
}

export function scheduleEmailWorker(): void {
  if (!configured()) {
    console.log("Email worker disabled; set EMAIL_ENABLED=true, SES_REGION, and SES_FROM_EMAIL to enable it");
    return;
  }
  if (workerTimer) return;
  workerTimer = setInterval(() => void runEmailWorker(), Math.max(15_000, EMAIL_POLL_MS));
  workerTimer.unref();
  if (marketingConfigured() && !marketingTimer) {
    marketingTimer = setInterval(
      () => void runMarketingWinbackScheduler().then(() => runEmailWorker()),
      Math.max(60 * 60_000, EMAIL_MARKETING_SCAN_MS)
    );
    marketingTimer.unref();
    void runMarketingWinbackScheduler().then(() => runEmailWorker());
  }
  void runEmailWorker();
}

export async function runEmailWorker(): Promise<void> {
  if (!configured() || workerRunning) return;
  workerRunning = true;
  try {
    while (true) {
      const delivery = await claimNextDelivery();
      if (!delivery) break;
      await processDelivery(delivery);
    }
  } catch (error) {
    console.error("Email worker failed:", safeErrorMessage(error));
  } finally {
    workerRunning = false;
  }
}

async function claimNextDelivery(): Promise<EmailDeliveryRow | null> {
  const rows = await prisma.$queryRaw<EmailDeliveryRow[]>`
    UPDATE "EmailDelivery"
    SET "status" = 'processing',
        "attempts" = "attempts" + 1,
        "updatedAt" = NOW()
    WHERE "id" = (
      SELECT "id"
      FROM "EmailDelivery"
      WHERE ("status" = 'scheduled' AND "scheduledAt" <= NOW())
         OR ("status" = 'processing' AND "updatedAt" < NOW() - INTERVAL '15 minutes')
      ORDER BY "scheduledAt" ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1
    )
    RETURNING "id", "userId", "kind", "expectedExpiresAt", "activityAnchorAt", "attempts"
  `;
  return rows[0] ?? null;
}

async function processDelivery(delivery: EmailDeliveryRow): Promise<void> {
  try {
    const lifecycle = isLifecycleEmailKind(delivery.kind);
    const marketing = isMarketingWinbackKind(delivery.kind);
    if ((!lifecycle && !marketing)
      || lifecycle && !delivery.expectedExpiresAt
      || marketing && !delivery.activityAnchorAt) {
      await finishDelivery(delivery.id, "cancelled", "unsupported_kind");
      return;
    }

    const preference = await prisma.emailPreference.findUnique({
      where: { userId: delivery.userId },
      select: {
        marketingStatus: true,
        subscriptionBillingEmailsEnabled: true,
        serviceSuppressedAt: true,
        billingIssueAt: true
      }
    });
    if (preference?.serviceSuppressedAt) {
      await finishDelivery(delivery.id, "suppressed", "service_email_suppressed");
      return;
    }
    if (!categoryAllowsEmail(delivery.kind, preference)) {
      await finishDelivery(delivery.id, "suppressed", "email_category_unsubscribed");
      return;
    }

    if (marketing) {
      if (preference?.billingIssueAt) {
        await finishDelivery(delivery.id, "cancelled", "billing_issue_active");
        return;
      }
      const lastActivityAt = await latestMeaningfulActivityAt(delivery.userId);
      if (!lastActivityAt || lastActivityAt > new Date(delivery.activityAnchorAt!.getTime() + 1_000)) {
        await finishDelivery(delivery.id, "cancelled", "user_became_active");
        return;
      }
      const recentServiceEmail = await prisma.emailDelivery.findFirst({
        where: {
          userId: delivery.userId,
          kind: { notIn: marketingWinbackKinds() },
          status: "sent",
          sentAt: { gte: new Date(Date.now() - 72 * 60 * 60_000) }
        },
        orderBy: { sentAt: "desc" },
        select: { sentAt: true }
      });
      if (recentServiceEmail?.sentAt) {
        await prisma.emailDelivery.update({
          where: { id: delivery.id },
          data: {
            status: "scheduled",
            scheduledAt: new Date(recentServiceEmail.sentAt.getTime() + 72 * 60 * 60_000),
            attempts: { decrement: 1 },
            lastError: "paused_after_service_email"
          }
        });
        return;
      }
    }

    const entitlement = lifecycle
      ? await prisma.revenueCatEntitlement.findFirst({
        where: { userId: delivery.userId },
        orderBy: { updatedAt: "desc" },
        select: { isActive: true, expiresAt: true, store: true, productId: true }
      })
      : null;
    if (lifecycle && delivery.kind !== "billing_issue"
      && (!entitlement?.isActive || !sameInstant(entitlement.expiresAt, delivery.expectedExpiresAt))) {
        await finishDelivery(delivery.id, "cancelled", "trial_state_changed");
        return;
      }

    const { data, error } = await supabaseAdmin.auth.admin.getUserById(delivery.userId);
    const address = data.user?.email?.trim();
    if (error || !address || !data.user?.email_confirmed_at) {
      await finishDelivery(delivery.id, "skipped", error ? "auth_lookup_failed" : "no_confirmed_email");
      return;
    }

    const emailChoicesURL = EMAIL_UNSUBSCRIBE_SECRET
      ? `${EMAIL_PUBLIC_BASE_URL}/email/unsubscribe?token=${encodeURIComponent(createMarketingUnsubscribeToken(delivery.userId))}`
      : undefined;
    const email = isMarketingWinbackKind(delivery.kind)
      ? renderMarketingWinbackEmail({
        kind: delivery.kind,
        callToActionURL: EMAIL_MARKETING_CTA_URL,
        postalAddress: EMAIL_MARKETING_POSTAL_ADDRESS,
        unsubscribeURL: emailChoicesURL!
      })
      : (() => {
        const manageSubscriptionURL = subscriptionURL(
          entitlement?.store ?? null,
          entitlement?.productId ?? null,
          delivery.kind === "billing_issue"
        );
        return isTrialEndingKind(delivery.kind)
          ? renderTrialEndingEmail({
            expiresAt: delivery.expectedExpiresAt!,
            hoursRemaining: delivery.kind === "trial_ending_48h" ? 48 : 24,
            manageSubscriptionURL,
            emailChoicesURL
          })
          : delivery.kind === "trial_cancelled_winback"
            ? renderCancelledTrialEmail({
              expiresAt: delivery.expectedExpiresAt!,
              manageSubscriptionURL,
              emailChoicesURL
            })
            : renderBillingIssueEmail({ manageSubscriptionURL, emailChoicesURL });
      })();
    const currentDelivery = await prisma.emailDelivery.findUnique({
      where: { id: delivery.id },
      select: { status: true }
    });
    if (currentDelivery?.status !== "processing") return;

    const headers = [
      { Name: "X-ChillScript-Message-Kind", Value: delivery.kind },
      { Name: "X-ChillScript-Delivery-ID", Value: delivery.id }
    ];
    if (marketing) {
      const unsubscribeURL = `${EMAIL_PUBLIC_BASE_URL}/email/unsubscribe?token=${encodeURIComponent(
        createMarketingUnsubscribeToken(delivery.userId)
      )}`;
      headers.push(
        { Name: "List-Unsubscribe", Value: `<${unsubscribeURL}>` },
        { Name: "List-Unsubscribe-Post", Value: "List-Unsubscribe=One-Click" },
        { Name: "List-ID", Value: "ChillScript Win-back <winback.chillnoteai.com>" },
        { Name: "Feedback-ID", Value: `${delivery.kind}:chillscript:marketing` }
      );
    }

    const response = await client().send(new SendEmailCommand({
      FromEmailAddress: marketing ? SES_MARKETING_FROM_EMAIL : SES_FROM_EMAIL,
      Destination: { ToAddresses: [address] },
      ReplyToAddresses: SES_REPLY_TO_EMAIL ? [SES_REPLY_TO_EMAIL] : undefined,
      ConfigurationSetName: SES_CONFIGURATION_SET || undefined,
      EmailTags: SES_CONFIGURATION_SET ? [
        { Name: "delivery_id", Value: delivery.id },
        { Name: "email_kind", Value: delivery.kind }
      ] : undefined,
      Content: {
        Simple: {
          Subject: { Data: email.subject, Charset: "UTF-8" },
          Body: {
            Html: { Data: email.html, Charset: "UTF-8" },
            Text: { Data: email.text, Charset: "UTF-8" }
          },
          Headers: headers
        }
      }
    }));
    await prisma.emailDelivery.update({
      where: { id: delivery.id },
      data: {
        status: "sent",
        sentAt: new Date(),
        providerMessageId: response.MessageId ?? null,
        lastError: null
      }
    });
  } catch (error) {
    const reason = safeErrorMessage(error).slice(0, 500);
    if (delivery.attempts < 5) {
      const retryMinutes = Math.min(60, 2 ** delivery.attempts);
      await prisma.emailDelivery.updateMany({
        where: { id: delivery.id, status: "processing" },
        data: {
          status: "scheduled",
          scheduledAt: new Date(Date.now() + retryMinutes * 60_000),
          lastError: reason
        }
      });
    } else {
      await finishDelivery(delivery.id, "failed", reason);
    }
  }
}

async function finishDelivery(id: string, status: string, lastError: string): Promise<void> {
  await prisma.emailDelivery.update({ where: { id }, data: { status, lastError } });
}

const preferenceSchema = z.object({ marketingSubscribed: z.boolean() });

function unsubscribeSignature(userId: string): string {
  return createHmac("sha256", EMAIL_UNSUBSCRIBE_SECRET).update(userId).digest("base64url");
}

export function createMarketingUnsubscribeToken(userId: string): string {
  if (!EMAIL_UNSUBSCRIBE_SECRET) throw new Error("EMAIL_UNSUBSCRIBE_SECRET is not configured");
  return `${userId}.${unsubscribeSignature(userId)}`;
}

export function verifyMarketingUnsubscribeToken(token: string): string | null {
  if (!EMAIL_UNSUBSCRIBE_SECRET) return null;
  const separator = token.lastIndexOf(".");
  if (separator <= 0) return null;
  const userId = token.slice(0, separator);
  const signature = token.slice(separator + 1);
  const expected = unsubscribeSignature(userId);
  const receivedBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  return receivedBuffer.length === expectedBuffer.length
    && timingSafeEqual(receivedBuffer, expectedBuffer) ? userId : null;
}

async function unsubscribe(token: string): Promise<boolean> {
  const userId = verifyMarketingUnsubscribeToken(token);
  if (!userId) return false;
  try {
    await prisma.emailPreference.upsert({
      where: { userId },
      create: { userId, marketingStatus: "unsubscribed", marketingUnsubscribedAt: new Date() },
      update: { marketingStatus: "unsubscribed", marketingUnsubscribedAt: new Date() }
    });
    await prisma.emailDelivery.updateMany({
      where: {
        userId,
        kind: { in: [...marketingWinbackKinds(), "trial_cancelled_winback"] },
        status: { in: ["scheduled", "processing"] }
      },
      data: { status: "cancelled", lastError: "marketing_unsubscribed" }
    });
    return true;
  } catch (error) {
    console.error("Email unsubscribe failed:", safeErrorMessage(error));
    return false;
  }
}

async function unsubscribeCategories(userId: string, categories: UnsubscribeCategory[]): Promise<void> {
  if (categories.length === 0) return;
  const now = new Date();
  await prisma.$transaction(async (tx) => {
    await tx.emailPreference.upsert({
      where: { userId },
      create: {
        userId,
        ...(categories.includes("marketing")
          ? { marketingStatus: "unsubscribed", marketingUnsubscribedAt: now } : {}),
        ...(categories.includes("subscription_billing") ? { subscriptionBillingEmailsEnabled: false } : {})
      },
      update: {
        ...(categories.includes("marketing")
          ? { marketingStatus: "unsubscribed", marketingUnsubscribedAt: now } : {}),
        ...(categories.includes("subscription_billing") ? { subscriptionBillingEmailsEnabled: false } : {})
      }
    });
    const kinds = [
      ...categories.includes("marketing") ? [...marketingWinbackKinds(), "trial_cancelled_winback"] : [],
      ...categories.includes("subscription_billing")
        ? ["trial_ending_48h", "trial_ending_24h", "billing_issue"] : []
    ];
    await tx.emailDelivery.updateMany({
      where: { userId, kind: { in: kinds }, status: { in: ["scheduled", "processing"] } },
      data: { status: "cancelled", lastError: "email_category_unsubscribed" }
    });
  });
}

export function registerEmailRoutes(app: Express, auth: RequestHandler): void {
  registerEmailAppOpenRoute(app);
  app.get("/email/preferences", auth, async (req, res) => {
    try {
      const preference = await prisma.emailPreference.findUnique({ where: { userId: req.userId! } });
      res.json({
        marketingSubscribed: marketingEmailsEnabled(preference),
        subscriptionBillingEmailsEnabled: preference?.subscriptionBillingEmailsEnabled !== false
      });
    } catch (error) {
      console.error("Email preference lookup failed:", safeErrorMessage(error));
      res.status(500).json({ error: "Unable to load email preference" });
    }
  });

  app.put("/email/preferences", auth, async (req, res) => {
    const parsed = preferenceSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid email preference" });
      return;
    }
    try {
      const subscribed = parsed.data.marketingSubscribed;
      await upsertUser(req.userId!);
      await prisma.emailPreference.upsert({
        where: { userId: req.userId! },
        create: {
          userId: req.userId!,
          marketingStatus: subscribed ? "subscribed" : "unsubscribed",
          marketingConsentedAt: subscribed ? new Date() : null,
          marketingConsentSource: subscribed ? "app_settings" : null,
          marketingUnsubscribedAt: subscribed ? null : new Date()
        },
        update: {
          marketingStatus: subscribed ? "subscribed" : "unsubscribed",
          marketingConsentedAt: subscribed ? new Date() : undefined,
          marketingConsentSource: subscribed ? "app_settings" : undefined,
          marketingUnsubscribedAt: subscribed ? null : new Date()
        }
      });
      if (!subscribed) {
        await prisma.emailDelivery.updateMany({
          where: {
            userId: req.userId!,
            kind: { in: [...marketingWinbackKinds(), "trial_cancelled_winback"] },
            status: { in: ["scheduled", "processing"] }
          },
          data: { status: "cancelled", lastError: "marketing_unsubscribed" }
        });
      }
      res.json({ marketingSubscribed: subscribed });
    } catch (error) {
      console.error("Email preference update failed:", safeErrorMessage(error));
      res.status(500).json({ error: "Unable to update email preference" });
    }
  });

  app.get("/email/unsubscribe", async (req, res) => {
    const token = typeof req.query.token === "string" ? req.query.token : "";
    const userId = verifyMarketingUnsubscribeToken(token);
    res.setHeader("Cache-Control", "no-store");
    if (!userId) {
      res.status(400).type("html").send(renderEmailChoicesPage("", null, "invalid"));
      return;
    }
    try {
      const preference = await prisma.emailPreference.findUnique({ where: { userId } });
      res.type("html").send(renderEmailChoicesPage(token, preference));
    } catch (error) {
      console.error("Email choices lookup failed:", safeErrorMessage(error));
      res.status(500).type("html").send("Unable to load email choices. Please try again later.");
    }
  });
  app.post("/email/unsubscribe", express.urlencoded({ extended: false }), async (req, res) => {
    const token = typeof req.query.token === "string" ? req.query.token : "";
    const success = await unsubscribe(token);
    if (!success) {
      res.status(400).type("html").send(renderEmailChoicesPage("", null, "invalid"));
      return;
    }
    res.type("html").send("<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Unsubscribed | ChillScript</title><body style=\"font-family:-apple-system,sans-serif;padding:48px;background:#f6f5f2;color:#17181b\"><h1>You’re unsubscribed.</h1><p>You will no longer receive ChillScript marketing emails.</p></body></html>");
  });
  app.post("/email/unsubscribe/choices", express.urlencoded({ extended: false }), async (req, res) => {
    const token = typeof req.query.token === "string" ? req.query.token : "";
    const userId = verifyMarketingUnsubscribeToken(token);
    const categories = parseUnsubscribeCategories(req.body?.unsubscribe);
    res.setHeader("Cache-Control", "no-store");
    if (!userId || !categories) {
      res.status(400).type("html").send(renderEmailChoicesPage("", null, "invalid"));
      return;
    }
    try {
      if (categories.length === 0) {
        const preference = await prisma.emailPreference.findUnique({ where: { userId } });
        res.type("html").send(renderEmailChoicesPage(token, preference, "empty"));
        return;
      }
      await unsubscribeCategories(userId, categories);
      const preference = await prisma.emailPreference.findUnique({ where: { userId } });
      res.type("html").send(renderEmailChoicesPage(token, preference, "saved"));
    } catch (error) {
      console.error("Email choices update failed:", safeErrorMessage(error));
      res.status(500).type("html").send("Unable to save email choices. Please try again later.");
    }
  });
}
