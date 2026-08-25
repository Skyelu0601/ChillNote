import assert from "node:assert/strict";
import test from "node:test";
import { normalizeMediaLinkSections } from "./mediaLinkSections.js";
import { normalizeTranscriptParagraphs } from "./linkImportJobs.js";
import {
  instagramMetadataFromYtDlpInfo,
  isApifyFallbackReason,
  selectYtDlpBinary
} from "./tiktokTranscript.js";

test("TikTok can use a dedicated yt-dlp binary without downgrading other platforms", () => {
  const currentBinary = "/usr/local/bin/yt-dlp";
  const tikTokBinary = "/opt/chillnote/bin/yt-dlp-tiktok-2026.03.17";

  assert.equal(selectYtDlpBinary("tiktok", currentBinary, tikTokBinary), tikTokBinary);
  assert.equal(selectYtDlpBinary("youtube", currentBinary, tikTokBinary), currentBinary);
  assert.equal(selectYtDlpBinary("instagram", currentBinary, tikTokBinary), currentBinary);
});

test("Instagram metadata prefers yt-dlp uploader and description fields", () => {
  const metadata = instagramMetadataFromYtDlpInfo({
    title: "Fallback title",
    description: "Reel caption",
    uploader: "Creator Name",
    uploader_id: "creator.handle",
    channel: "Fallback Channel",
    channel_id: "fallback-channel-id",
    webpage_url: "https://www.instagram.com/reel/example/"
  });

  assert.deepEqual(metadata, {
    resolvedURL: "https://www.instagram.com/reel/example/",
    title: "Reel caption",
    authorName: "Creator Name",
    authorUniqueID: "creator.handle"
  });
});

test("Instagram metadata falls back to channel fields and ignores blanks", () => {
  const metadata = instagramMetadataFromYtDlpInfo({
    title: "  Reel title  ",
    description: "   ",
    uploader: "",
    uploader_id: "  ",
    channel: " Channel Name ",
    channel_id: " channel-handle "
  });

  assert.deepEqual(metadata, {
    resolvedURL: undefined,
    title: "Reel title",
    authorName: "Channel Name",
    authorUniqueID: "channel-handle"
  });
});

test("missing media-link preferences use the iOS transcript-only canonical format", () => {
  assert.deepEqual(normalizeMediaLinkSections(undefined), {
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: true
  });
});

test("new clients can request transcript-only notes", () => {
  assert.deepEqual(normalizeMediaLinkSections({
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: true
  }), {
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: true
  });
});

test("an empty section selection falls back to transcript-only", () => {
  assert.deepEqual(normalizeMediaLinkSections({
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: false
  }), {
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: true
  });
});

test("creator transcript paragraphs never retain visual blank lines", () => {
  assert.equal(
    normalizeTranscriptParagraphs("\r\nFirst paragraph.\r\n \r\nSecond paragraph.\u2029\u2029Third paragraph.\r\n"),
    "First paragraph.\nSecond paragraph.\nThird paragraph."
  );
});

test("Apify fallback is limited to TikTok media-fetch failures", () => {
  assert.equal(isApifyFallbackReason("tiktok", "media_fetch_failed"), true);
  assert.equal(isApifyFallbackReason("tiktok", "media_fetch_forbidden"), true);
  assert.equal(isApifyFallbackReason("tiktok", "media_fetch_login_required"), true);
  assert.equal(isApifyFallbackReason("tiktok", "media_fetch_rate_limited"), true);
  assert.equal(isApifyFallbackReason("youtube", "media_fetch_failed"), false);
  assert.equal(isApifyFallbackReason("instagram", "media_fetch_failed"), false);
  assert.equal(isApifyFallbackReason("tiktok", "transcription_failed"), false);
  assert.equal(isApifyFallbackReason("tiktok", "media_too_large"), false);
});
