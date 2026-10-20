import assert from "node:assert/strict";
import test from "node:test";
import {
  buildAPNsPayload,
  buildFCMRequest,
  classifyFCMResponse,
  isRetryablePushError,
  payloadForDelivery,
  runNotificationWorker
} from "./pushNotifications.js";
import { prisma } from "./db.js";

test("retired weekly topics have no push payload", () => {
  assert.equal(payloadForDelivery({ kind: "weekly_topics_ready", noteId: null }), null);
});

test("queued weekly pushes are cancelled while later import notifications still run", async (t) => {
  const queued = [
    { id: "weekly-1", userId: "user-1", kind: "weekly_topics_ready", noteId: null, dedupeKey: "weekly:1", attempts: 1 },
    { id: "import-1", userId: "user-1", kind: "import_ready", noteId: "note-1", dedupeKey: "import:1", attempts: 1 }
  ];
  const updates: any[] = [];
  const originalUpdate = prisma.notificationDelivery.update;
  const originalFindDevices = prisma.pushDevice.findMany;
  t.after(() => {
    prisma.notificationDelivery.update = originalUpdate;
    prisma.pushDevice.findMany = originalFindDevices;
  });
  t.mock.method(prisma, "$queryRaw", async () => {
    const row = queued.shift();
    return row ? [row] : [];
  });
  prisma.notificationDelivery.update = t.mock.fn(async (args: any) => {
    updates.push(args);
    return {};
  }) as any;
  const devices = t.mock.fn(async () => {
    assert.equal(updates[0]?.where.id, "weekly-1");
    assert.equal(updates[0]?.data.status, "cancelled");
    return [];
  });
  prisma.pushDevice.findMany = devices as any;

  await runNotificationWorker();

  assert.equal(devices.mock.callCount(), 1);
  assert.deepEqual(updates.map(item => [item.where.id, item.data.status]), [
    ["weekly-1", "cancelled"],
    ["import-1", "skipped"]
  ]);
});

test("note notifications carry their note route on APNs and FCM", () => {
  const payload = payloadForDelivery({ kind: "import_ready", noteId: "note-123" });
  assert.ok(payload);

  assert.equal((buildAPNsPayload(payload) as any).noteId, "note-123");
  const fcm = buildFCMRequest("firebase-installation-id", payload, "import:job") as any;
  assert.deepEqual(fcm.message.data, {
    kind: "import_ready",
    route: "note",
    noteId: "note-123"
  });
  assert.equal(fcm.message.android.notification.title_loc_key, "notification_import_ready_title");
  assert.equal(fcm.message.android.notification.body_loc_key, "notification_import_ready_body");
  assert.equal(fcm.message.android.notification.channel_id, "content_updates");
});

test("first creation reminders retain their localized payload", () => {
  const payload = payloadForDelivery({ kind: "first_creation", noteId: "note-123" });
  assert.ok(payload);
  assert.deepEqual((buildAPNsPayload(payload) as any).aps.alert, {
    "title-loc-key": "notification.first_creation.title",
    "loc-key": "notification.first_creation.body"
  });
  assert.equal(payload.androidTitleKey, "notification_first_creation_title");
  assert.equal(payload.androidBodyKey, "notification_first_creation_body");
});

test("FCM response classification invalidates only expired registrations", () => {
  const expired = classifyFCMResponse(404, JSON.stringify({
    error: { status: "NOT_FOUND" }
  }));
  const unavailable = classifyFCMResponse(503, JSON.stringify({
    error: { status: "UNAVAILABLE" }
  }));
  const invalidPayload = classifyFCMResponse(400, JSON.stringify({
    error: { status: "INVALID_ARGUMENT" }
  }));

  assert.equal(expired.invalidateToken, true);
  assert.equal(unavailable.invalidateToken, false);
  assert.equal(isRetryablePushError(unavailable.reason), true);
  assert.equal(invalidPayload.invalidateToken, false);
  assert.equal(isRetryablePushError(invalidPayload.reason), false);
});

test("FCM quota and missing configuration errors are retryable", () => {
  const quota = classifyFCMResponse(429, JSON.stringify({
    error: {
      status: "RESOURCE_EXHAUSTED",
      details: [{ errorCode: "QUOTA_EXCEEDED" }]
    }
  }));

  assert.equal(quota.ok, false);
  assert.equal(isRetryablePushError(quota.reason), true);
  assert.equal(isRetryablePushError("fcm_RESOURCE_EXHAUSTED"), true);
  assert.equal(isRetryablePushError("fcm_not_configured"), true);
  assert.equal(isRetryablePushError("fcm_oauth_status_503"), true);
});
