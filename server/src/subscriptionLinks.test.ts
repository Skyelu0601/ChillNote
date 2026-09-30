import assert from "node:assert/strict";
import test from "node:test";
import { subscriptionURL } from "./subscriptionLinks.js";

test("billing recovery links lead to the store payment controls", () => {
  assert.equal(subscriptionURL("app_store", null, true), "https://apps.apple.com/account/billing");
  assert.equal(
    subscriptionURL("play_store", "pro_annual:annual-base", true),
    "https://play.google.com/store/account/subscriptions?sku=pro_annual&package=com.sponteoai.chillscript"
  );
  assert.equal(subscriptionURL("google_play", null, true), "https://play.google.com/store/account/subscriptions");
  assert.equal(subscriptionURL("app_store"), "https://apps.apple.com/account/subscriptions");
});
