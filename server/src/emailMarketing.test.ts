import assert from "node:assert/strict";
import test from "node:test";
import { nextMarketingWinbackSchedule } from "./emailMarketing.js";

const DAY_MS = 24 * 60 * 60 * 1_000;
const activity = new Date("2026-09-01T00:00:00Z");

test("first win-back becomes eligible after seven inactive days", () => {
  assert.equal(nextMarketingWinbackSchedule({
    lastActivityAt: activity,
    deliveries: [],
    now: new Date(activity.getTime() + 6 * DAY_MS)
  }), null);

  const now = new Date(activity.getTime() + 7 * DAY_MS);
  assert.deepEqual(nextMarketingWinbackSchedule({ lastActivityAt: activity, deliveries: [], now }), {
    kind: "marketing_winback_1",
    scheduledAt: now
  });
});

test("second win-back waits seven days after the first was sent", () => {
  const firstSentAt = new Date("2026-09-08T12:00:00Z");
  const now = new Date(firstSentAt.getTime() + 7 * DAY_MS);
  assert.deepEqual(nextMarketingWinbackSchedule({
    lastActivityAt: activity,
    deliveries: [{ kind: "marketing_winback_1", status: "sent", sentAt: firstSentAt }],
    now
  }), { kind: "marketing_winback_2", scheduledAt: now });
});

test("third win-back waits sixteen days and completed sequences do not restart", () => {
  const firstSentAt = new Date("2026-09-08T00:00:00Z");
  const secondSentAt = new Date("2026-09-15T00:00:00Z");
  const now = new Date(secondSentAt.getTime() + 16 * DAY_MS);
  const deliveries = [
    { kind: "marketing_winback_1" as const, status: "sent", sentAt: firstSentAt },
    { kind: "marketing_winback_2" as const, status: "sent", sentAt: secondSentAt }
  ];
  assert.deepEqual(nextMarketingWinbackSchedule({ lastActivityAt: activity, deliveries, now }), {
    kind: "marketing_winback_3",
    scheduledAt: now
  });
  assert.equal(nextMarketingWinbackSchedule({
    lastActivityAt: activity,
    deliveries: [...deliveries, { kind: "marketing_winback_3", status: "sent", sentAt: now }],
    now
  }), null);
});

test("a pending or failed step never skips ahead", () => {
  assert.equal(nextMarketingWinbackSchedule({
    lastActivityAt: activity,
    deliveries: [{ kind: "marketing_winback_1", status: "scheduled", sentAt: null }],
    now: new Date("2026-10-01T00:00:00Z")
  }), null);
});
