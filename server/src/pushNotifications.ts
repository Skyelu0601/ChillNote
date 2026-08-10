import http2 from "node:http2";
import { importPKCS8, SignJWT, type KeyLike } from "jose";
import { prisma } from "./db.js";

type PushEnvironment = "sandbox" | "production";
type NotificationKind = "import_ready" | "first_creation" | "weekly_topics_ready";

type DeliveryRow = {
  id: string;
  userId: string;
  kind: NotificationKind;
  noteId: string | null;
  dedupeKey: string;
  attempts: number;
};

type PushDeviceRow = {
  id: string;
  token: string;
  environment: PushEnvironment;
  locale: string;
  timeZone: string;
};

type LocalizedAlert = {
  "title-loc-key": string;
  "title-loc-args"?: string[];
  "loc-key": string;
  "loc-args"?: string[];
};

const APNS_KEY_ID = process.env.APNS_KEY_ID?.trim() || "";
const APNS_TEAM_ID = process.env.APNS_TEAM_ID?.trim() || "";
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID?.trim() || "com.sponteoai.chillnote";
const APNS_PRIVATE_KEY = (process.env.APNS_PRIVATE_KEY ?? "").replace(/\\n/g, "\n");
const FIRST_CREATION_DELAY_HOURS = Number(process.env.FIRST_CREATION_REMINDER_DELAY_HOURS ?? 24);
const NOTIFICATION_POLL_MS = Number(process.env.NOTIFICATION_POLL_MS ?? 60_000);

let workerTimer: NodeJS.Timeout | null = null;
let workerRunning = false;
let signingKeyPromise: Promise<KeyLike> | null = null;
let providerTokenCache: { value: string; expiresAt: number } | null = null;

export async function registerPushDevice(params: {
  userId: string;
  token: string;
  environment: PushEnvironment;
  locale: string;
  timeZone: string;
  authorizationStatus?: string;
}): Promise<void> {
  await prisma.pushDevice.upsert({
    where: { token: params.token },
    create: {
      userId: params.userId,
      token: params.token,
      environment: params.environment,
      locale: normalizedLocale(params.locale),
      timeZone: normalizedTimeZone(params.timeZone),
      authorizationStatus: params.authorizationStatus,
      isActive: true,
      lastSeenAt: new Date()
    },
    update: {
      userId: params.userId,
      environment: params.environment,
      locale: normalizedLocale(params.locale),
      timeZone: normalizedTimeZone(params.timeZone),
      authorizationStatus: params.authorizationStatus,
      isActive: true,
      lastSeenAt: new Date()
    }
  });
}

export async function deactivatePushDevice(userId: string, token: string): Promise<void> {
  await prisma.pushDevice.updateMany({
    where: { userId, token },
    data: { isActive: false }
  });
}

export async function scheduleImportCompletionNotifications(params: {
  jobId: string;
  userId: string;
  noteId: string;
}): Promise<void> {
  const now = new Date();
  const firstCreationAt = new Date(
    now.getTime() + Math.max(1, FIRST_CREATION_DELAY_HOURS) * 60 * 60 * 1000
  );

  await prisma.$transaction([
    prisma.notificationDelivery.upsert({
      where: { dedupeKey: `import_ready:${params.jobId}` },
      create: {
        userId: params.userId,
        kind: "import_ready",
        dedupeKey: `import_ready:${params.jobId}`,
        noteId: params.noteId,
        scheduledAt: now
      },
      update: {}
    }),
    prisma.notificationDelivery.upsert({
      where: { dedupeKey: `first_creation:${params.userId}` },
      create: {
        userId: params.userId,
        kind: "first_creation",
        dedupeKey: `first_creation:${params.userId}`,
        noteId: params.noteId,
        scheduledAt: firstCreationAt
      },
      update: {}
    })
  ]);

  void runNotificationWorker();
}

export function scheduleNotificationWorker(): void {
  if (workerTimer) return;
  workerTimer = setInterval(() => {
    void runNotificationWorker();
  }, Math.max(15_000, NOTIFICATION_POLL_MS));
  workerTimer.unref();
  void runNotificationWorker();
}

export async function runNotificationWorker(): Promise<void> {
  if (workerRunning) return;
  workerRunning = true;
  try {
    while (true) {
      const delivery = await claimNextDelivery();
      if (!delivery) break;
      await processDelivery(delivery);
    }
  } catch (error) {
    console.error("Push notification worker failed:", safeErrorMessage(error));
  } finally {
    workerRunning = false;
  }
}

async function claimNextDelivery(): Promise<DeliveryRow | null> {
  const rows = await prisma.$queryRaw<DeliveryRow[]>`
    UPDATE "NotificationDelivery"
    SET "status" = 'processing',
        "attempts" = "attempts" + 1,
        "updatedAt" = NOW()
    WHERE "id" = (
      SELECT "id"
      FROM "NotificationDelivery"
      WHERE "status" = 'scheduled'
        AND "scheduledAt" <= NOW()
      ORDER BY "scheduledAt" ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1
    )
    RETURNING "id", "userId", "kind", "noteId", "dedupeKey", "attempts"
  `;
  return rows[0] ?? null;
}

async function processDelivery(delivery: DeliveryRow): Promise<void> {
  try {
    if (delivery.kind === "first_creation" && await userHasCreatedDraft(delivery.userId)) {
      await markDelivery(delivery.id, "cancelled");
      return;
    }

    const devices = await prisma.pushDevice.findMany({
      where: { userId: delivery.userId, isActive: true },
      select: {
        id: true,
        token: true,
        environment: true,
        locale: true,
        timeZone: true
      }
    }) as PushDeviceRow[];

    if (devices.length === 0) {
      await markDelivery(delivery.id, "skipped", "no_active_device");
      return;
    }

    const payload = await payloadForDelivery(delivery);
    if (!payload) {
      await markDelivery(delivery.id, "cancelled");
      return;
    }

    let sentCount = 0;
    const errors: string[] = [];
    for (const device of devices) {
      const result = await sendToAPNs(device, payload, delivery.dedupeKey);
      if (result.ok) {
        sentCount += 1;
      } else {
        errors.push(result.reason);
        if (result.invalidateToken) {
          await prisma.pushDevice.update({
            where: { id: device.id },
            data: { isActive: false }
          });
        }
      }
    }

    if (sentCount > 0) {
      await markDelivery(delivery.id, "sent");
    } else if (delivery.attempts < 3 && errors.some(isRetryablePushError)) {
      await retryDelivery(delivery.id, delivery.attempts, errors.join(","));
    } else {
      await markDelivery(delivery.id, "failed", errors.join(",").slice(0, 500));
    }
  } catch (error) {
    if (delivery.attempts < 3) {
      await retryDelivery(delivery.id, delivery.attempts, safeErrorMessage(error));
    } else {
      await markDelivery(delivery.id, "failed", safeErrorMessage(error).slice(0, 500));
    }
  }
}

async function payloadForDelivery(
  delivery: DeliveryRow
): Promise<{ aps: { alert: LocalizedAlert; sound: string }; kind: string; route?: string; noteId?: string } | null> {
  if (delivery.kind === "import_ready") {
    return {
      aps: {
        alert: {
          "title-loc-key": "notification.import_ready.title",
          "loc-key": "notification.import_ready.body"
        },
        sound: "default"
      },
      kind: delivery.kind,
      route: "note",
      noteId: delivery.noteId ?? undefined
    };
  }

  if (delivery.kind === "first_creation") {
    return {
      aps: {
        alert: {
          "title-loc-key": "notification.first_creation.title",
          "loc-key": "notification.first_creation.body"
        },
        sound: "default"
      },
      kind: delivery.kind,
      route: "note",
      noteId: delivery.noteId ?? undefined
    };
  }

  if (delivery.kind === "weekly_topics_ready") {
    return {
      aps: {
        alert: {
          "title-loc-key": "notification.weekly_topics.title",
          "loc-key": "notification.weekly_topics.body"
        },
        sound: "default"
      },
      kind: delivery.kind,
      route: "weekly_topics"
    };
  }

  // Cancel deliveries for notification kinds removed from the product.
  return null;
}

async function userHasCreatedDraft(userId: string): Promise<boolean> {
  const count = await prisma.note.count({
    where: {
      userId,
      deletedAt: null,
      section: { in: ["drafts", "published"] }
    }
  });
  return count > 0;
}

async function sendToAPNs(
  device: PushDeviceRow,
  payload: object,
  collapseID: string
): Promise<{ ok: boolean; reason: string; invalidateToken: boolean }> {
  if (!isAPNsConfigured()) {
    return { ok: false, reason: "apns_not_configured", invalidateToken: false };
  }

  const authority = device.environment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const providerToken = await apnsProviderToken();
  const client = http2.connect(authority);

  return await new Promise((resolve) => {
    let body = "";
    const request = client.request({
      ":method": "POST",
      ":path": `/3/device/${device.token}`,
      authorization: `bearer ${providerToken}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(Date.now() / 1000) + 24 * 60 * 60),
      "apns-collapse-id": collapseID.slice(0, 64)
    });
    request.setEncoding("utf8");
    request.on("response", (headers) => {
      const status = Number(headers[":status"] ?? 500);
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        client.close();
        const reason = parseAPNsReason(body) ?? `status_${status}`;
        resolve({
          ok: status === 200,
          reason,
          invalidateToken: status === 410 || reason === "BadDeviceToken" || reason === "Unregistered"
        });
      });
    });
    request.on("error", (error) => {
      client.close();
      resolve({ ok: false, reason: safeErrorMessage(error), invalidateToken: false });
    });
    request.end(JSON.stringify(payload));
  });
}

async function apnsProviderToken(): Promise<string> {
  const now = Date.now();
  if (providerTokenCache && providerTokenCache.expiresAt > now + 60_000) {
    return providerTokenCache.value;
  }
  signingKeyPromise ??= importPKCS8(APNS_PRIVATE_KEY, "ES256");
  const key = await signingKeyPromise;
  const issuedAt = Math.floor(now / 1000);
  const value = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APNS_KEY_ID })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt(issuedAt)
    .sign(key);
  providerTokenCache = { value, expiresAt: now + 50 * 60 * 1000 };
  return value;
}

function isAPNsConfigured(): boolean {
  return Boolean(APNS_KEY_ID && APNS_TEAM_ID && APNS_PRIVATE_KEY && APNS_BUNDLE_ID);
}

async function markDelivery(id: string, status: string, lastError?: string): Promise<void> {
  await prisma.notificationDelivery.update({
    where: { id },
    data: {
      status,
      sentAt: status === "sent" ? new Date() : undefined,
      lastError
    }
  });
}

async function retryDelivery(id: string, attempts: number, lastError: string): Promise<void> {
  const delayMinutes = Math.min(30, 2 ** Math.max(1, attempts));
  await prisma.notificationDelivery.update({
    where: { id },
    data: {
      status: "scheduled",
      scheduledAt: new Date(Date.now() + delayMinutes * 60 * 1000),
      lastError: lastError.slice(0, 500)
    }
  });
}

function isRetryablePushError(reason: string): boolean {
  return reason === "apns_not_configured"
    || reason === "status_429"
    || reason.startsWith("status_5")
    || reason.includes("ECONN")
    || reason.includes("socket")
    || reason.includes("timeout");
}

function normalizedLocale(locale: string): string {
  return locale.trim().slice(0, 35) || "en";
}

function normalizedTimeZone(timeZone: string): string {
  const candidate = timeZone.trim() || "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: candidate }).format();
    return candidate;
  } catch {
    return "UTC";
  }
}

function parseAPNsReason(body: string): string | null {
  try {
    const parsed = JSON.parse(body) as { reason?: string };
    return parsed.reason ?? null;
  } catch {
    return null;
  }
}

function safeErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
