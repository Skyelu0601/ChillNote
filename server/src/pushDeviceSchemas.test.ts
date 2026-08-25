import assert from "node:assert/strict";
import test from "node:test";
import { pushDeviceDeleteSchema, pushDeviceSchema } from "./pushDeviceSchemas.js";

const common = {
  environment: "production",
  locale: "en-US",
  timeZone: "America/Los_Angeles",
  authorizationStatus: "authorized"
};

test("keeps legacy iOS registration payloads compatible", () => {
  const result = pushDeviceSchema.parse({
    ...common,
    token: "ab".repeat(32)
  });

  assert.equal(result.platform, "ios");
  assert.equal(result.token, "ab".repeat(32));
});

test("accepts current Android FIDs and legacy FCM registration tokens", () => {
  const fid = pushDeviceSchema.parse({
    ...common,
    platform: "android",
    token: "cM2g49YxR2mEXAMPLE123"
  });
  const legacyToken = pushDeviceSchema.parse({
    ...common,
    platform: "android",
    token: "eXaMplE:APA91bHf-registration_token-1234567890"
  });

  assert.equal(fid.platform, "android");
  assert.equal(legacyToken.platform, "android");
});

test("rejects malformed or platform-mismatched registrations", () => {
  assert.equal(pushDeviceSchema.safeParse({
    ...common,
    platform: "android",
    token: "has whitespace in it"
  }).success, false);
  assert.equal(pushDeviceSchema.safeParse({
    ...common,
    platform: "ios",
    token: "cM2g49YxR2mEXAMPLE123"
  }).success, false);
});

test("deactivation accepts either APNs or FCM identifiers", () => {
  assert.equal(pushDeviceDeleteSchema.safeParse({ token: "ab".repeat(32) }).success, true);
  assert.equal(
    pushDeviceDeleteSchema.safeParse({ token: "cM2g49YxR2mEXAMPLE123" }).success,
    true
  );
});
