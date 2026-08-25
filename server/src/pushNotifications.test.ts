import assert from "node:assert/strict";
import test from "node:test";
import {
  buildAPNsPayload,
  buildFCMRequest,
  classifyFCMResponse,
  isRetryablePushError,
  payloadForDelivery
} from "./pushNotifications.js";

test("weekly topics payload preserves each platform's semantic localization keys", () => {
  const payload = payloadForDelivery({ kind: "weekly_topics_ready", noteId: null });
  assert.ok(payload);

  assert.deepEqual(buildAPNsPayload(payload), {
    aps: {
      alert: {
        "title-loc-key": "notification.weekly_topics.title",
        "loc-key": "notification.weekly_topics.body"
      },
      sound: "default"
    },
    kind: "weekly_topics_ready",
    route: "weekly_topics",
    noteId: undefined
  });

  const fcm = buildFCMRequest("firebase-installation-id", payload, "weekly:user:report") as any;
  assert.equal(fcm.message.fid, "firebase-installation-id");
  assert.deepEqual(fcm.message.data, {
    kind: "weekly_topics_ready",
    route: "weekly_topics"
  });
  assert.equal(
    fcm.message.android.notification.title_loc_key,
    "notification_weekly_topics_title"
  );
  assert.equal(
    fcm.message.android.notification.body_loc_key,
    "notification_weekly_topics_body"
  );
  assert.equal(fcm.message.android.notification.channel_id, "content_updates");
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
