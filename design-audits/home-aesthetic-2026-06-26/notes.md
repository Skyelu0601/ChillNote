# ChillScript Home Aesthetic Audit

Date: 2026-06-26
Device: iPhone 17 simulator, iOS 26.2

## Captured Screens

1. `01-home-current.jpg` - current logged-in home screen.
2. `02-home-more-ways.jpg` - quick capture menu expanded from the bottom dock.
3. `03-home-redesign-concept.png` - generated direction reference, not a final implementation spec.

## Quick Read

The current home screen feels calm, light, and fairly Apple-native. The main weakness is that the first screen does not immediately communicate the product's strongest promise: capture creator inspiration from voice, links, screenshots, and media, then turn it into structured notes.

The expanded "More Ways" sheet has clearer product value than the default home screen. That suggests a low-risk visual improvement: expose a small version of those capture choices on the home screen instead of hiding them behind the plus button.

## Strengths

- The page is clean and uncluttered.
- The floating bottom dock is memorable and gives voice capture a persistent place.
- The section picker is compact and easy to scan.
- The expanded quick capture sheet has useful, concrete actions: Paste Link, Photo or Image, Audio or Video File.

## Main Risks

1. The home screen is too quiet on first arrival.
   - The large middle area is mostly empty, so the screen reads more like a blank notes list than an AI creator capture tool.

2. The core value is hidden behind the plus button.
   - Link, photo, and media import are strong differentiators, but they only appear after opening the menu.

3. The mic is visually important but not emotionally inviting enough.
   - It is centered, but in idle state it uses a pale capsule, so the primary action does not feel as decisive as it could.

4. The welcome note competes with the actual first action.
   - It explains what to do, but it looks like normal note content, so it does not strongly guide the next step.

5. Typography direction is slightly split.
   - The serif title and section labels create a softer editorial feel. That can be nice, but the app's creator-tool use case may benefit from a slightly more utility-forward hierarchy.

## Recommended Direction

1. Add a compact "Capture inspiration" row above the notes list.
   - Four small actions: Voice, Link, Photo, File.
   - This can reuse the same actions already available in the More Ways sheet.
   - Keep it light: small rounded tiles or a segmented action strip, not a big hero card.

2. Make the mic the strongest visual action.
   - Use brand blue for the idle mic circle or a stronger blue ring.
   - Keep the plus and text-note buttons secondary.

3. Turn the welcome state into an onboarding action card.
   - Instead of a normal note card saying "click the yellow button", show a short "Start with..." card or inline prompt.
   - Suggested structure: title, one-line benefit, 2-3 quick starts.

4. Reduce pure empty space with functional content, not decoration.
   - If there are few notes, show recent capture types or suggested first actions.
   - Avoid decorative gradients or blobs; the current product is strongest when it feels like a clean tool.

5. Keep the current calm palette.
   - Do not do a heavy redesign.
   - Use blue more intentionally for primary actions and selection states.

## Implementation Notes

- `HomeBodyView.swift` currently places the header, section picker, notes list, and floating `ChatInputBar`.
- `ChatInputBar.swift` already has the More Ways actions and the idle dock.
- The lowest-risk implementation path is to create a small home quick-capture component in the content area and wire it to the existing paste link, image import, media file, and record actions.

## Accessibility Notes

- From screenshots alone, the visible touch targets look mostly large enough.
- The expanded sheet truncates long subtitles, which may reduce clarity for larger text settings.
- Any quick-capture row should keep labels visible, not icon-only, because the actions are not all obvious at first glance.
