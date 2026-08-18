import assert from "node:assert/strict";
import test from "node:test";
import {
  extractApifyStoreID,
  isTrustedApifyMediaURL,
  makeApifyMediaRequestHeaders,
  parseApifyTikTokDataset,
  shouldSendApifyAuthorization
} from "./apifyTikTok.js";

test("Apify TikTok dataset prefers the downloaded media URL", () => {
  const result = parseApifyTikTokDataset([{
    id: "7618559483647773960",
    mediaUrls: ["https://api.apify.com/v2/key-value-stores/store123/records/video.mp4"],
    videoMeta: {
      duration: 74,
      downloadAddr: "https://v19-webapp.tiktok.com/original.mp4"
    }
  }]);

  assert.deepEqual(result, {
    mediaURL: "https://api.apify.com/v2/key-value-stores/store123/records/video.mp4",
    videoID: "7618559483647773960",
    durationSec: 74
  });
});

test("Apify TikTok dataset falls back to videoMeta downloadAddr", () => {
  const result = parseApifyTikTokDataset([{
    id: 123,
    videoMeta: {
      downloadAddr: "https://v19-webapp.tiktok.com/video.mp4"
    }
  }]);

  assert.equal(result.mediaURL, "https://v19-webapp.tiktok.com/video.mp4");
  assert.equal(result.videoID, "123");
});

test("Apify TikTok dataset rejects provider error items", () => {
  assert.throws(
    () => parseApifyTikTokDataset([{ errorCode: "POST_NOT_FOUND" }]),
    /POST_NOT_FOUND/
  );
});

test("Apify store ID is only extracted from the trusted API host", () => {
  assert.equal(
    extractApifyStoreID("https://api.apify.com/v2/key-value-stores/store123/records/video.mp4"),
    "store123"
  );
  assert.equal(
    extractApifyStoreID("https://api.apify.com.evil.example/v2/key-value-stores/store123/records/video.mp4"),
    undefined
  );
});

test("Apify authorization is never sent to third-party media hosts", () => {
  assert.equal(
    shouldSendApifyAuthorization("https://api.apify.com/v2/key-value-stores/store123/records/video.mp4"),
    true
  );
  assert.equal(
    shouldSendApifyAuthorization("https://v19-webapp.tiktok.com/video.mp4"),
    false
  );
  assert.equal(
    shouldSendApifyAuthorization("http://api.apify.com/v2/key-value-stores/store123/records/video.mp4"),
    false
  );
  assert.equal(
    makeApifyMediaRequestHeaders("https://v19-webapp.tiktok.com/video.mp4", "secret-token").Authorization,
    undefined
  );
  assert.equal(
    makeApifyMediaRequestHeaders(
      "https://api.apify.com/v2/key-value-stores/store123/records/video.mp4",
      "secret-token"
    ).Authorization,
    "Bearer secret-token"
  );
});

test("Apify media downloads are restricted to Apify and TikTok hosts", () => {
  assert.equal(
    isTrustedApifyMediaURL("https://api.apify.com/v2/key-value-stores/store123/records/video.mp4"),
    true
  );
  assert.equal(isTrustedApifyMediaURL("https://v19-webapp.tiktok.com/video.mp4"), true);
  assert.equal(isTrustedApifyMediaURL("https://cdn.tiktokcdn.com/video.mp4"), true);
  assert.equal(isTrustedApifyMediaURL("https://api.apify.com.evil.example/video.mp4"), false);
  assert.equal(isTrustedApifyMediaURL("http://127.0.0.1/internal"), false);
});
