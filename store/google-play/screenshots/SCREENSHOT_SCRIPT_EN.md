# ChillScript Google Play Screenshot Set (English)

## Format and visual direction

- Final size: 1080 × 1920 px (9:16), accepted by Google Play.
- Content direction: lead with the creator's saved-idea library, then show the
  workflow from viral video to transcript, AI repurposing, weekly ideas, and
  teleprompter recording.
- Background: warm off-white.
- Headline: one black line plus one ChillScript-blue benefit line.
- Product UI: real Pixel 7 captures only; no generated or redrawn interface.
- System status and navigation areas are cropped where they do not add product value.
- Source captures: `store/google-play/source-captures/pixel7/`.
- Platform marks: Android drawable resources under `android/app/src/main/res/drawable-nodpi/`.
- Generator: `store/google-play/scripts/generate_pixel7_store_screenshots.py`.
- The generator reads only Android-owned project assets.

## Story order

### 1. Never Lose a / Content Idea Again.

- Purpose: lead with the creator's organized content library and recurring value.
- Screen: Inbox with TikTok, Instagram, and YouTube source cards.
- Source: `Screenshot_20260825-094618.png`.

### 2. Viral Video In. / Transcript Out.

- Purpose: explain the core input-to-output promise in one glance.
- Screen: the TikTok note with the completed transcript.
- Supporting visual: TikTok, YouTube, and Reels marks sourced from Android.
- Source: `Screenshot_20260825-094425.png`.

### 3. Rewrite, Repurpose, / and Create More.

- Purpose: show that saved inspiration becomes usable creator output.
- Main screen: the AI Skills list.
- Overlay: a real Hook result, showing the output without redrawing the interface.
- Sources: `Screenshot_20260825-094514.png` and `Screenshot_20260825-094530.png`.

### 4. Fresh Post Ideas. / Every Week.

- Purpose: show the recurring value that brings creators back.
- Screen: Weekly Post Ideas with related saved sources.
- Source: `Screenshot_20260825-094627.png`.

### 5. Record With a / Teleprompter.

- Purpose: complete the workflow from idea to camera-ready script.
- Screen: the Record tab with “Script ready” and the recording action.
- Source: `Screenshot_20260825-094549.png`.

## Upload notes

- Upload in the numbered order above; the first three screenshots carry the main conversion story.
- Use `en-US` for the default English listing.
- Localized output folders use Google Play language codes: `de-DE`, `es-ES`,
  `es-419`, `fr-FR`, `ja-JP`, `ko-KR`, `zh-CN`, and `zh-TW`.
- Screenshot headlines are localized; the product panels remain unmodified real
  Pixel 7 captures.
- Run `python3.12 store/google-play/scripts/generate_pixel7_store_screenshots.py`
  from the repository root to regenerate all 45 screenshots and their previews.
- Pass `--locale <code>` to generate only one locale; repeat the option for
  multiple locales.
