import assert from "node:assert/strict";
import test from "node:test";
import { normalizeMediaLinkSections } from "./mediaLinkSections.js";
import { instagramMetadataFromYtDlpInfo } from "./tiktokTranscript.js";

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

test("legacy media-link section preferences remain enabled by default", () => {
  assert.deepEqual(normalizeMediaLinkSections(undefined), {
    showDescription: true,
    showAuthor: true,
    showHook: true,
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
