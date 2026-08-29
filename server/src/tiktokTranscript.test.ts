import assert from "node:assert/strict";
import test from "node:test";
import { normalizeMediaLinkSections } from "./mediaLinkSections.js";
import { normalizeTranscriptParagraphs } from "./linkImportJobs.js";
import {
  buildYtDlpInfoArgs,
  instagramMetadataFromYtDlpInfo,
  isApifyFallbackReason,
  selectBestCaption,
  selectYtDlpBinary
} from "./tiktokTranscript.js";

test("TikTok can use a dedicated yt-dlp binary without downgrading other platforms", () => {
  const currentBinary = "/usr/local/bin/yt-dlp";
  const tikTokBinary = "/opt/chillnote/bin/yt-dlp-tiktok-2026.03.17";

  assert.equal(selectYtDlpBinary("tiktok", currentBinary, tikTokBinary), tikTokBinary);
  assert.equal(selectYtDlpBinary("youtube", currentBinary, tikTokBinary), currentBinary);
  assert.equal(selectYtDlpBinary("instagram", currentBinary, tikTokBinary), currentBinary);
});

test("YouTube metadata excludes auto-translated subtitle tracks", () => {
  const url = "https://www.youtube.com/watch?v=example";
  assert.deepEqual(buildYtDlpInfoArgs("youtube", url), [
    "--dump-json",
    "--skip-download",
    "--no-playlist",
    "--no-warnings",
    "--extractor-args",
    "youtube:skip=translated_subs",
    url
  ]);
  assert.equal(buildYtDlpInfoArgs("instagram", url).includes("youtube:skip=translated_subs"), false);
});

test("explicit source language beats an English subtitle", () => {
  const selected = selectBestCaption({
    language: "es-ES",
    subtitles: {
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }],
      es: [{ ext: "vtt", url: "https://captions.example/es.vtt" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=spanish"
  });

  assert.equal(selected?.url, "https://captions.example/es.vtt");
});

test("Spanish automatic captions beat a manual English translation", () => {
  const selected = selectBestCaption({
    title: "Cómo crear vídeos para redes sociales",
    description: "The complete guide for you and your team, with more examples in the description.",
    subtitles: {
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }]
    },
    automatic_captions: {
      es: [{ ext: "json3", url: "https://captions.example/es.json3" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=spanish"
  });

  assert.equal(selected?.url, "https://captions.example/es.json3");
});

test("a sole YouTube automatic-caption language identifies the original track", () => {
  const selected = selectBestCaption({
    title: "Episode 1",
    subtitles: {
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }]
    },
    automatic_captions: {
      "es-orig": [{ ext: "json3", url: "https://captions.example/es.json3" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=spanish"
  });

  assert.equal(selected?.url, "https://captions.example/es.json3");
});

test("French metadata selects French instead of English captions", () => {
  const selected = selectBestCaption({
    title: "Comment créer une vidéo avec ces astuces",
    subtitles: {
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }],
      fr: [{ ext: "vtt", url: "https://captions.example/fr.vtt" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=french"
  });

  assert.equal(selected?.url, "https://captions.example/fr.vtt");
});

test("German metadata selects German instead of English captions", () => {
  const selected = selectBestCaption({
    title: "Wie du bessere Videos mit diesen Tipps erstellst",
    subtitles: {
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }],
      de: [{ ext: "vtt", url: "https://captions.example/de.vtt" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=german"
  });

  assert.equal(selected?.url, "https://captions.example/de.vtt");
});

test("unknown source language keeps extractor order instead of forcing English", () => {
  const selected = selectBestCaption({
    subtitles: {
      pt: [{ ext: "vtt", url: "https://captions.example/pt.vtt" }],
      en: [{ ext: "vtt", url: "https://captions.example/en.vtt" }]
    }
  }, {
    platform: "youtube",
    resolvedURL: "https://www.youtube.com/watch?v=unknown"
  });

  assert.equal(selected?.url, "https://captions.example/pt.vtt");
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
