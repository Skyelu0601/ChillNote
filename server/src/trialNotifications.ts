import type { Prisma } from "@prisma/client";
import { z } from "zod";
import type { RevenueCatEntitlementSnapshot } from "./revenueCat.js";
import { subscriptionURL } from "./subscriptionLinks.js";

const trialDetails = z.object({
  type: z.literal("trial"),
  expiresAt: z.string().datetime(),
  productId: z.string().min(1),
  store: z.enum(["app_store", "play_store", "google_play"]),
  autoRenew: z.boolean()
});
export function readTrialDetails(value: unknown) {
  const parsed = trialDetails.safeParse(value);
  return parsed.success ? parsed.data : null;
}

/** Only a verified, active store trial can create this inbox item. */
export async function syncTrialNotification(
  tx: Pick<Prisma.TransactionClient, "appNotification">,
  userId: string,
  snapshot: RevenueCatEntitlementSnapshot
) {
  if (!snapshot.active || !snapshot.trial) return;
  const trial = snapshot.trial;
  const details = { type: "trial", expiresAt: trial.expiresAt.toISOString(),
    productId: trial.productId, store: trial.store, autoRenew: trial.autoRenew };
  // Extending the same trial must not create another unread confirmation.
  const dedupeKey = `trial:${trial.store}:${trial.productId}:${trial.startedAt?.toISOString() ?? details.expiresAt}`;
  // Existing clients still understand welcome_pro and ignore the additive details.
  // Refreshes update current renewal state without reviving the unread badge.
  await tx.appNotification.upsert({
    where: { userId_dedupeKey: { userId, dedupeKey } },
    create: { userId, dedupeKey, kind: "welcome_pro", details },
    update: { details }
  });
}

export function maskEmail(address: string | null | undefined): string | null {
  const email = address?.trim();
  if (!email) return null;
  const at = email.lastIndexOf("@");
  if (at < 1 || at === email.length - 1) return null;
  return `${email[0]}***${email.slice(at)}`;
}

export type TrialEmailIdentity = { email: string | null; verified: boolean };
type Delivery = { status: string; scheduledAt: Date; expectedExpiresAt: Date | null;
  sentAt: Date | null; bouncedAt?: Date | null; complainedAt?: Date | null };

export function trialInboxContent(params: {
  details: NonNullable<ReturnType<typeof readTrialDetails>>;
  delivery: Delivery | null;
  identity: TrialEmailIdentity | null;
  emailConfigured: boolean;
  emailEnabled: boolean;
  suppressed: boolean;
  activeTrial: boolean;
  now?: Date;
}) {
  const { details, delivery, identity } = params;
  const now = params.now ?? new Date();
  const expired = Date.parse(details.expiresAt) <= now.getTime();
  const matching = delivery?.expectedExpiresAt?.toISOString() === details.expiresAt;
  const scheduled48HoursBefore = delivery != null
    && Math.abs(delivery.scheduledAt.getTime() - (Date.parse(details.expiresAt) - 48 * 60 * 60_000)) < 60_000;
  let reminderStatus = "pending";
  if (expired || !params.activeTrial) reminderStatus = "ended";
  else if (!details.autoRenew) reminderStatus = "cancelled";
  else if (!params.emailConfigured || !params.emailEnabled || params.suppressed
    || !identity?.verified || !maskEmail(identity.email)) reminderStatus = "unavailable";
  else if (matching && delivery?.status === "sent" && delivery.sentAt
    && !delivery.bouncedAt && !delivery.complainedAt) reminderStatus = "sent";
  else if (matching && delivery && ["scheduled", "processing"].includes(delivery.status)
    && !delivery.bouncedAt && !delivery.complainedAt) {
    // A retry may move scheduledAt; it cannot promise the original 48-hour timing.
    reminderStatus = scheduled48HoursBefore && delivery.scheduledAt > now ? "scheduled" : "pending";
  }
  else if (matching && delivery) reminderStatus = "unavailable";
  else if (Date.parse(details.expiresAt) - now.getTime() <= 48 * 60 * 60_000) reminderStatus = "unavailable";
  return {
    expiresAt: details.expiresAt,
    autoRenew: details.autoRenew,
    reminderStatus,
    reminderAt: matching && ["scheduled", "sent"].includes(reminderStatus)
      ? (reminderStatus === "sent" ? delivery!.sentAt! : delivery!.scheduledAt).toISOString() : null,
    // Sent records do not store the original recipient, which may since have changed.
    maskedEmail: reminderStatus === "scheduled" ? maskEmail(identity?.email) : null,
    manageSubscriptionURL: subscriptionURL(details.store)
  };
}
