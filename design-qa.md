**Source visual truth**

- Path: `/Users/luwenting/Downloads/IMG_1265.PNG`
- State: onboarding paywall, annual plan selected, English locale.
- Pixel size: 1206 × 2622 (iPhone screenshot, approximately 3× density).

**Rendered implementation**

- Path: `/tmp/chillscript-paywall-spacing-v3.png`
- State: onboarding paywall, annual plan selected, Simplified Chinese locale, StoreKit product data loaded.
- Viewport: iPhone 16 Pro simulator, 393 × 852 points.
- Pixel size: 1206 × 2622 (approximately 3× density).
- Density normalization: source and implementation have identical pixel dimensions and were compared without resampling.

**Comparison evidence**

- Full-view side-by-side: `/tmp/chillscript-paywall-spacing-comparison.png`.
- The source is on the left and the revised implementation is on the right.
- No focused crop was required because the 2412 × 2622 combined image keeps the wordmark, price card, CTA, and legal links clearly readable.

**Findings**

- Fonts and typography: the ChillScript wordmark is visibly larger than the source screenshot, matching the requested adjustment. Title hierarchy and price emphasis remain intact; locale-specific wrapping is correct.
- Spacing and layout rhythm: the price card, CTA, no-trial notice, and legal links now read as one continuous purchase group. No excessive gap remains between price and CTA.
- Colors and visual tokens: existing ChillScript blue, white cards, gray secondary text, borders, and background treatment are preserved.
- Image quality and asset fidelity: the existing vector/code-native brand wordmark and platform icon libraries remain sharp at device density; no placeholder assets were introduced.
- Copy and content: annual/weekly selection, annual price, weekly equivalent, CTA, restore, terms, and privacy remain present. The source is English while the implementation evidence is Simplified Chinese; the visible content is semantically equivalent.
- No actionable P0, P1, or P2 issues remain.

**Comparison history**

- Iteration 1: moving the CTA directly below the price removed the requested gap, but left a new large gap before the legal footer. Result remained blocked.
- Fix: moved the no-trial notice and legal links into the same scroll-flow purchase group on iOS and Android.
- Iteration 2 evidence: `/tmp/chillscript-paywall-spacing-v3.png` and `/tmp/chillscript-paywall-spacing-comparison.png` show compact, consistent vertical rhythm with all controls visible.

**Implementation Checklist**

- [x] Increase ChillScript wordmark size on iOS and Android.
- [x] Place CTA directly after the selected price card.
- [x] Keep no-trial and legal actions visually connected to the CTA.
- [x] Verify annual/weekly selection content remains intact.
- [x] Build both platforms and compare the rendered iOS screen with the source screenshot.

**Follow-up Polish**

- Device chrome differs between the two captures because they were taken on different iPhone models; this does not affect app-owned content.

final result: passed

---

# Onboarding paywall redesign QA — 2026-08-28

**Source visual truth**

- Path: `/Users/luwenting/.codex/generated_images/01a0439b-48fc-79e0-906e-338f16a4f718/exec-94bb5bcd-b38c-421b-8468-29b680f5b813.png`
- State: onboarding paywall, Annual selected, eligible 7-day introductory offer, English locale.
- Pixel size: 852 × 1856.

**Rendered implementation**

- Path: unavailable; no iOS Simulator is currently booted.
- Intended viewport: iPhone 16 Pro, 393 × 852 points, native simulator density.
- State: onboarding paywall launched with `-SubscriptionScreenshotMode`.

**Comparison evidence**

- Source visual was opened and used as the implementation target.
- A rendered implementation screenshot could not be captured because all installed simulators are shut down.
- Full-view and focused-region comparison are therefore blocked; no visual fidelity judgment is being inferred from the successful build alone.

**Findings**

- Build and localization compilation pass, but visual QA remains incomplete.
- Fonts and typography, spacing and layout rhythm, colors, icons, and copy must be checked against the source after a simulator is booted.
- Annual/Weekly interaction and the eligibility-dependent trial copy must also be exercised in the rendered screen.

**Comparison history**

- No rendered comparison iteration is available yet.

**Implementation Checklist**

- [x] Implement the selected pure-white paywall layout.
- [x] Restore Annual introductory-offer display from StoreKit metadata and eligibility.
- [x] Keep Weekly free of trial copy.
- [x] Pass i18n lint and iOS Simulator compilation.
- [ ] Capture the Annual state on a booted simulator.
- [ ] Tap Weekly and verify the CTA/trust copy changes.
- [ ] Compare source and implementation together and fix P0/P1/P2 differences.

final result: blocked

---

# Android onboarding paywall parity QA — 2026-08-28

**Source visual truth**

- Path: `/Users/luwenting/.codex/generated_images/01a0439b-48fc-79e0-906e-338f16a4f718/exec-94bb5bcd-b38c-421b-8468-29b680f5b813.png`
- State: onboarding paywall, Annual selected, eligible 7-day introductory offer, English locale.
- Pixel size: 852 × 1846.

**Rendered implementation**

- Annual state: `/tmp/chillscript-android-verify.png`.
- Weekly state: `/tmp/chillscript-android-paywall-weekly-fixed.png`.
- Device: Medium Phone API 36.1 emulator, 1080 × 2400 px at 420 dpi (approximately 411 × 914 dp including system bars).
- Locale: Simplified Chinese.
- Pricing data: debug-only preview values; the release purchase path continues to use live Google Play product and offer metadata.

**Comparison evidence**

- Full-view side-by-side: `/tmp/chillscript-android-paywall-comparison.png`.
- The source is on the left and the Android implementation is on the right.
- Both captures were normalized to a height of 1856 px and padded to equal widths before comparison.
- System bars, localized text length, and native Material icon shapes were treated as expected platform differences.

**Findings**

- Fonts and typography: the title, feature copy, plan names, annual total, weekly equivalent, CTA, and legal text preserve the source hierarchy without oversized price emphasis or truncation.
- Spacing and layout rhythm: the seven benefits, two plan cards, CTA, trust copy, and legal links fit in one coherent vertical purchase flow at the tested viewport.
- Colors and visual tokens: the pure-white background, black body text, ChillScript blue selection treatment, subtle card borders, and blue CTA match the selected visual direction.
- Icons and asset quality: native Material icons remain sharp at device density and map semantically to every feature; no placeholder assets were introduced.
- Copy and content: Annual shows the seven-day trial and annual total on the left with the weekly equivalent on the right. Weekly contains no trial promise and shows its weekly price.
- Interaction QA initially found that selecting Weekly left the Annual CTA label visible. The selection condition was corrected and the post-fix screenshot confirms `继续周付套餐` with Weekly selected.
- No actionable P0, P1, or P2 visual issues remain.

**Implementation Checklist**

- [x] Open the paywall directly from the debug launch path instead of stopping on onboarding page one.
- [x] Verify Annual selected state and seven-day trial copy.
- [x] Verify Weekly selected state, CTA, and no-trial trust copy.
- [x] Compare the reference and rendered implementation together.
- [x] Keep debug preview pricing isolated from release behavior.
- [x] Pass Android build, unit tests, and localization validation.

**Follow-up Polish**

- The Simplified Chinese Restore label is naturally wider than the English source label.
- Material icon silhouettes differ slightly from the iOS/source icon set while preserving meaning and Android-native rendering.

final result: passed
