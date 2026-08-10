**Comparison Target**

- Source visual truth: `/Users/luwenting/.codex/generated_images/019f68b8-ee5e-7d31-a116-794b2d9c9b83/exec-338d6a57-02e8-4b64-96b0-1f859160043f.png`
- Implementation screenshot: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_307aa9f2-f3c5-4a46-b8bb-c8a5790cfb7a.jpg`
- Final full-view comparison: `/Users/luwenting/.codex/visualizations/2026/07/16/019f68b8-ee5e-7d31-a116-794b2d9c9b83/skill-result-comparison-final.png`
- Viewport: iPhone 16 Pro simulator, 368 x 800 rendered capture, light app surface
- State: Hook Skill Result with six generated hooks; default state in the final screenshot. Individual-copy interaction and localized success toast were also exercised in the simulator.

**Findings**

- No actionable P0, P1, or P2 differences remain.
- [P3] The implementation uses ChillScript's localized app copy and current design tokens instead of reproducing the mock's English-only labels and exact generated-image typography. This is intentional product alignment.
- [P3] The source image shows the post-copy success state, while the final full-view comparison uses the default state. Runtime UI inspection after tapping an individual copy button confirmed the localized `已复制` toast, close control, and copied state are present.

**Required Fidelity Surfaces**

- Fonts and typography: Native SwiftUI typography preserves the source hierarchy: compact uppercase type labels, readable hook copy, semibold title and actions. Wrapping remains legible at 368 pt width.
- Spacing and layout rhythm: The grouped white result container, inset dividers, 44 pt copy controls, rounded sheet, compact header, and fixed bottom action region match the source structure. The two global actions now share one horizontal container.
- Colors and visual tokens: ChillScript's existing near-white background, white cards, subtle borders, secondary text, and brand blue are consistently used and closely match the source palette.
- Image quality and asset fidelity: No raster assets are required for the result list. The existing creator-skill icon and SF Symbols remain sharp at simulator density.
- Copy and content: Real localized app labels are used. AI output remains in its generated language and each hook preserves its original content.

**Comparison History**

1. Initial comparison evidence: `/Users/luwenting/.codex/visualizations/2026/07/16/019f68b8-ee5e-7d31-a116-794b2d9c9b83/skill-result-comparison.png`
   - Earlier P2 finding: the two bottom actions were vertically stacked, unlike the compact horizontal action bar in the source, reducing visible result space.
   - Fix made: when exactly two Home result actions are available, they now render side by side in one shared rounded container with a divider.
2. Post-fix evidence: `/Users/luwenting/.codex/visualizations/2026/07/16/019f68b8-ee5e-7d31-a116-794b2d9c9b83/skill-result-comparison-final.png`
   - The grouped result structure, copy affordances, and horizontal action bar now align with the selected source style.
3. Interaction follow-up:
   - Simulator accessibility snapshot exposed six `复制这个区块` buttons.
   - After tapping a block, the runtime snapshot exposed `已复制`, a success checkmark, and a `关闭` control.

**Focused Region Comparison**

- A separate crop was not needed because labels, hook copy, dividers, copy controls, and the bottom action bar are all clearly readable in the normalized 736 x 800 side-by-side comparison.

**Implementation Checklist**

- [x] Preserve Markdown as the canonical note content.
- [x] Parse Hook Pack output into independently actionable rows.
- [x] Parse Caption Pack and Repurpose Pack `##` sections into independently actionable blocks.
- [x] Fall back to the original Markdown preview for unsupported or ambiguous output.
- [x] Add individual copy, haptic feedback, copied state, and localized confirmation toast.
- [x] Keep full-result save/copy actions available.
- [x] Verify the iOS build, localized strings, and simulator interaction.

**Follow-up Polish**

- P3: Consider changing the toast text from generic `Copied` to a skill-aware message such as `Hook copied` if future usability testing shows the extra specificity is useful.

final result: passed

---

# 首页首次视频引导配色 — 方案 1

**对照目标**

- 视觉基准：`/Users/luwenting/development/ChillNote/audit/home-first-action-colors-2026-08-09/source-option-1.png`
- 实现截图：`/Users/luwenting/development/ChillNote/audit/home-first-action-colors-2026-08-09/implementation-option-1.png`
- 并排对照：`/Users/luwenting/development/ChillNote/audit/home-first-action-colors-2026-08-09/option-1-comparison.png`
- 设备与状态：iPhone 16 Pro、iOS 18.6、简体中文、浅色模式、Inbox 首次操作引导预览。
- 尺寸说明：视觉基准为 862 × 1825 px；实现截图为 1206 × 2622 px（@3x，对应 402 × 874 pt）；并排图将两者等比缩放至 1825 px 高。

**检查结果**

- 没有仍需处理的 P0、P1 或 P2 差异。
- 颜色语义与方案 1 一致：品牌蓝用于选中状态、Post Ideas、分享步骤与主按钮；青绿色只保留给 Creator Skills。
- 引导卡片恢复白色中性表面、细灰边框和灰色步骤连接线，不再混入暖金色背景与描边。
- 第二步归档图标继续使用黑色与浅灰背景，和主操作形成清晰层级。
- [P3] 实机截图包含真实 Dynamic Island 和系统状态栏，设备顶部比例与生成稿略有不同。
- [P3] 生成稿的主按钮带有非常轻微的明暗变化；实现按“无渐变”的配色方向使用项目现有纯品牌蓝。

**保真范围**

- 字体、字号、间距和布局保持现有 SwiftUI 实现不变。
- 图标继续使用现有 SF Symbols，没有新增位图资源。
- 所有文案与语义化本地化调用保持不变。
- 现有按钮关闭行为和无障碍语义保持不变。

**对照历史**

1. 首轮真实模拟器截图即匹配方案 1 的颜色层级。
2. 完整并排图中未发现需要再次修改的 P0、P1 或 P2 视觉差异，因此无需额外修复循环。

**验证清单**

- [x] iPhone 16 Pro、iOS 18.6 模拟器构建成功。
- [x] 应用安装、启动和指定预览状态截图成功。
- [x] 视觉基准与真实实现已并排比较。
- [x] 本次没有修改用户可见文案或国际化资源，因此无需运行国际化检查。

final result: passed

# 首页空状态卡片 — 方案 3

**对照目标**

- 视觉基准：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-08/source-option-3.png`
- 实现截图：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-08/implementation-option-3-drafts.jpg`
- 并排对照：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-08/option-3-comparison.png`
- 设备与状态：iPhone 16 Pro、iOS 18.6、浅色模式、英文 Drafts 空状态，368 × 800 px。

**检查结果**

- 没有仍需处理的 P0、P1 或 P2 差异。
- [P3] 实现使用项目已有 SF Symbols 和字体令牌，因此图标笔触与视觉稿中的定制插画略有差异；卡片层级、浅蓝色表面、信息结构和主要操作保持一致。
- [P3] 实现保留真实 iPhone 安全区与底部 Home Indicator，视觉稿没有完整呈现这些系统区域。

**功能与质量验证**

- [x] 同步、首次加载且列表为空时继续显示骨架屏，不提前出现空状态。
- [x] Drafts 的 `Browse Inbox` 已实际点击验证，会切换到 Inbox。
- [x] Published 的 `Browse Drafts` 已实际点击验证，会切换到 Drafts。
- [x] Inbox、Drafts、Published 和 Trash 使用各自的标题与说明。
- [x] 新增按钮文案覆盖项目现有 8 种语言，`npm run lint:i18n` 通过。
- [x] iPhone 16 Pro 模拟器构建和运行通过。

final result: passed

---

# 侧边栏成长轨迹统计 — 方案 1

**对照目标**

- 视觉基准：`/Users/luwenting/.codex/generated_images/019fdbe8-13f6-75e1-8c8f-ad3bb2482d5f/exec-9945debb-b083-4f3e-b151-e15e38af42d8.png`
- 最终实现截图：`/Users/luwenting/development/ChillNote/audit/sidebar-stats-2026-08-07/implementation-sidebar.png`
- 完整并排对照：`/Users/luwenting/development/ChillNote/audit/sidebar-stats-2026-08-07/full-comparison.png`
- 统计区域局部对照：`/Users/luwenting/development/ChillNote/audit/sidebar-stats-2026-08-07/stats-focused-comparison.png`
- 视口：iOS 18.6 模拟器，369 × 800 px 优化截图，浅色模式，简体中文。
- 源图尺寸：853 × 1844 px；先等比归一为 369 × 800 px，再和 369 × 800 px 的实现截图并排对照。实现和源图均为同一侧边栏展开状态。

**检查结果**

- 没有仍需处理的 P0、P1 或 P2 差异。
- [P3] 视觉稿用了两个装饰闪电，实现保留一个原生 `bolt.fill`，避免统计卡片在 320 pt 的真实侧边栏里显得拥挤。
- [P3] 实现卡片比视觉稿略紧凑，目的是保留现有导航和标签的可见空间；统计区域的信息层级、色彩和趋势图占比仍与方案一致。

**保真度检查**

- 字体与排版：标题保持衬线粗体层级，连续天数使用 36 pt 品牌蓝强调；本周数量和增长比例分别使用品牌蓝与青绿色，所有文字在 320 pt 宽度内无截断。
- 间距与布局：统计卡片保持现有 16 pt 侧边栏边距；标题、摘要、110 pt 趋势图按单列排列，没有挤压或覆盖下方导航。
- 颜色与视觉令牌：继续使用项目现有的 `accentPrimary`、`accentSecondary`、`bgSecondary` 和 `textSub`；浅蓝渐变只用于统计卡片和趋势面积，没有引入新的全局样式。
- 图片与图标质量：统计区域不需要位图素材。闪电使用 SF Symbol；折线和面积是由真实数据驱动的 SwiftUI 矢量图形，在模拟器截图中边缘清晰。
- 文案与内容：连续天数、近 7 天、今天、本周数量和周同比都来自真实记录日期；新增文案使用语义化 key，并覆盖项目现有 8 种语言。

**对照迭代历史**

1. 第一轮实现截图显示折线是硬折线、卡片略矮，而且摘要数字没有使用视觉稿中的强调色，记录为 P2。
2. 修正内容：折线改为平滑曲线；图表高度从 94 pt 增至 110 pt；本周数量改为品牌蓝，增长比例改为青绿色；闪电图标适度放大。
3. 第二轮完整与局部并排对照确认：标题、摘要、趋势面积、七日标签和今日高亮均清晰；早期 P2 已消除。

**运行与交互验证**

- 模拟器运行时无障碍快照识别到“连续创作 8 天。本周 14 篇 · 比上周 +27%”的完整统计摘要。
- 七日标签按当前语言显示，最后一天显示为“今天”。
- 收件箱和回收站仍是可点击按钮；统计区域没有改变原有导航行为。
- `npm run lint:i18n` 通过；iPhone 16 Pro（iOS 18.6）构建通过。

**后续微调**

- P3：如果真机上希望更接近视觉稿的夸张感，可以在不改变统计口径的前提下，将闪电背景再扩大 2–4 pt。

final result: passed

---

# Note Detail Header Action Dock — Option 3

**Comparison Target**

- Source visual truth: `/Users/luwenting/.codex/generated_images/019fae52-e72a-7700-a2b2-df184d557d88/call_uMjPDURceMaaKBprrM6zFuwk.png`
- Implementation screenshot: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_dec519b6-ad15-4b40-9be9-8bb40d135e32.jpg`
- Final normalized full-view comparison: `/tmp/chillnote_header_design_qa_compare_final.png`
- Final focused comparison: `/tmp/chillnote_header_design_qa_focus_final.png`
- Viewport: iPhone 17 simulator, 368 x 800 point optimized capture, light appearance
- Source pixels: 851 x 1847, normalized to 368 x 800
- Implementation pixels: 368 x 800
- State: Note detail idle state with AI Skills, Teleprompter Recording, and More Actions available

**Findings**

- No actionable P0, P1, or P2 differences remain.
- [P3] The generated source uses slightly softer rasterized icon edges and a marginally wider-looking outer capsule. The implementation uses native SF Symbols and exact 36-point hit areas inside a 124-point SwiftUI capsule, preserving sharper rendering and accessibility.

**Required Fidelity Surfaces**

- Fonts and typography: No text styling changed. The existing native note typography, date, tag label, wrapping, and hierarchy remain intact.
- Spacing and layout rhythm: Three 36-point circular controls use 4-point internal spacing and 4-point container padding. The single capsule, shared shadow, alignment, and action hierarchy match the source.
- Colors and visual tokens: AI uses `brandBlueSoft`, Teleprompter uses `brandBlue` with a white icon, More Actions uses a subtle `textSub` gray fill, and the shared surface uses `bgSecondary`.
- Image quality and asset fidelity: No raster assets are required. Native SF Symbols remain sharp and match the source icon meanings.
- Copy and content: No visible copy was added or changed. Existing localized accessibility labels remain attached to all three actions.

**Comparison History**

1. Initial valid comparison: `/tmp/chillnote_header_design_qa_compare_v2.png` and `/tmp/chillnote_header_design_qa_focus.png`
   - Earlier P2 finding: the More Actions circle was too close to white, weakening the three-level visual hierarchy from the selected source.
   - Fix made: changed the circle fill from `bgPrimary` to `textSub.opacity(0.08)` for a clearer neutral tier without adding another border or shadow.
2. Post-fix evidence: `/tmp/chillnote_header_design_qa_compare_final.png` and `/tmp/chillnote_header_design_qa_focus_final.png`
   - The AI, primary Teleprompter, and neutral More Actions tiers now read consistently inside one shared dock.
3. A preliminary capture showed the Home screen after relaunch and was excluded before comparison because it did not match the selected source state.

**Interaction Verification**

- AI Skills opened the creator-skill sheet and was dismissed successfully.
- Teleprompter Recording passed through the camera permission flow and opened the teleprompter camera on the next tap.
- More Actions opened the menu containing Export Markdown, Delete Note, and Delete Permanently.
- Simulator build completed with no warnings or errors. Internationalization lint passed.

**Implementation Checklist**

- [x] Group all three actions in one shared capsule.
- [x] Remove the three independent borders and shadows.
- [x] Preserve 36-point circular hit areas.
- [x] Give Teleprompter the primary solid-blue treatment.
- [x] Keep AI secondary with a pale-blue fill.
- [x] Keep More Actions neutral with a subtle gray fill.
- [x] Preserve localized accessibility labels and existing menu behavior.
- [x] Build, launch, exercise all three actions, and compare against the selected source.

**Follow-up Polish**

- P3: Revisit the shared shadow only if physical-device testing makes it appear heavier than the selected source under different display brightness.

final result: passed

---

# Link Import Pending Card — Option 1

**Comparison Target**

- Source visual truth: `/Users/luwenting/.codex/generated_images/019fadbb-e6f4-7b82-a05f-8e3bc99b9524/call_Luiv8YRD3qLcQqBzTamUYaby.png`
- Implementation screenshot: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_8e84631b-9b48-4e92-9bee-047b2113b006.jpg`
- Final normalized comparison: `/private/tmp/link-import-option1-custom-ring-comparison.png`
- Viewport: iPhone 16 Pro simulator, 368 x 800 point optimized capture, light appearance
- Source pixels: 2048 x 766; focused card crop: 1803 x 606
- Implementation pixels: 368 x 800; focused card crop: 324 x 101, normalized to 1803 x 562 for comparison
- State: Simplified Chinese link-import pending state rendered through the exact production component in a temporary debug-only screenshot host; the host was removed after capture.

**Findings**

- No actionable P0, P1, or P2 differences remain.
- [P3] The production card is intentionally more compact vertically than the generated source visual. This follows the real note-list density and avoids making a background task dominate the home feed.
- [P3] The simulator uses the localized Simplified Chinese copy and native system glyph rendering instead of the source visual's English copy.

**Required Fidelity Surfaces**

- Fonts and typography: The implementation uses the app's system sans-serif `bodyMedium` semibold title and `chillCaption` secondary copy. Hierarchy, wrapping, weight, and contrast remain legible at the real 368-point viewport.
- Spacing and layout rhythm: The nested tinted panel, border, oversized icon, and full-width progress bar are removed. The 24-point open activity ring, two-line text group, and three dots share the existing note-card surface with 12-point horizontal spacing and compact vertical rhythm.
- Colors and visual tokens: Existing `textMain`, `textSub`, `accentPrimary`, `cardBackground`, and `shadowColor` tokens are preserved. There are no new gradients, borders, or competing surface colors.
- Image quality and asset fidelity: The target contains no raster artwork. The implementation uses vector SwiftUI strokes for the custom open ring and vector circles for the three status dots, so all marks remain sharp at simulator density.
- Copy and content: The selected source meaning is preserved with concise localized title/body strings across all eight supported locales. The copy explicitly tells users they may continue browsing while processing finishes.

**Comparison History**

1. Initial implementation: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_253c2dc6-d6e8-4f5f-bb1b-91f3ae2e0059.jpg`
   - Earlier P2 finding: `.small` control size made the activity indicator visibly undersized relative to the selected source and the 24-point slot.
   - Fix made: changed the native `ProgressView` to `.regular` while retaining its 24 x 24 alignment frame.
2. Post-fix evidence: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_70a92660-d43d-43d8-9d73-4d39c6b5f570.jpg`
   - The indicator now has enough presence to anchor the status without recreating the oversized decorative circle from the old UI.

**Focused Region Comparison**

- The final combined image places the cropped source component and cropped simulator component in one comparison input. This focused crop makes typography, indicator scale, dots, card padding, and removal of the nested panel directly readable.

**Implementation Checklist**

- [x] Remove the nested blue-tinted card, border, sparkle treatment, and shimmer bar.
- [x] Use a rotating open ring matching the selected visual.
- [x] Add three subtle staggered breathing dots.
- [x] Preserve the existing outer note card and design tokens.
- [x] Update all supported localizations.
- [x] Pass i18n lint and simulator build.
- [x] Capture and compare the real production component.
- [x] Remove the temporary screenshot host and restore the normal app entry path.

**Follow-up Polish**

- P3: If later device testing shows the three dots are too quiet in motion, increase their minimum opacity slightly without increasing their size.

## Custom Ring Feedback Iteration

- User feedback: Prefer the open blue ring drawn in the selected source visual over the native iOS activity spinner.
- Fix: Replaced `ProgressView` with a 24-point rotating open ring using rounded stroke caps, a faint full-circle track, and an angular brand-blue gradient.
- Simulator evidence: `/var/folders/yp/tg7h91s544s4pyxgnctb5xph0000gn/T/screenshot_optimized_8e84631b-9b48-4e92-9bee-047b2113b006.jpg`
- Normalized comparison: `/private/tmp/link-import-option1-custom-ring-comparison.png`
- Result: The ring now matches the source's shape, open gap, rounded endpoints, blue tonal variation, and visual weight. No actionable P0, P1, or P2 differences remain.

final result: passed

---

# 首页周报第二版设计 QA

## 结论

- 最终结果：通过
- 验证设备：iPhone 16 Pro，iOS 18.6
- 验证语言：简体中文
- 验证状态：默认聚焦第 1 个选题，并验证切换到第 2 个选题

## 对照证据

- 视觉基准：`/Users/luwenting/.codex/generated_images/019fc137-2fce-76b2-ac20-b6b3a827578c/exec-547600b7-095a-4809-8fe8-8e8f9f65f52f.png`
- 实现截图：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-implementation-final.png`
- 并排对照：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-design-comparison.png`
- 基准图尺寸：853 × 1844（目标比例 390 × 844）
- 实现截图尺寸：1206 × 2622（@3x，对应 402 × 874 pt）
- 对照方式：将实现截图等比缩放到 1844 px 高，与基准图并排比较；完整页面中的标题、来源行和间距均可辨认，因此不需要额外局部裁切。

## 保真度检查

- 字体：建立了“灵感标签 → 日期 → 摘要 → 当前选题 → 来源 → 后续选题”的清晰层级；标题粗细和正文灰度与基准一致。
- 间距：顶部留白、区块间距、来源列表密度和分隔线节奏均与基准接近。
- 颜色：保留浅蓝头图、青绿色强调色、白色内容底和低对比度分隔线。
- 图标与素材：使用系统 SF Symbols，保证清晰度、深色模式兼容和无障碍表现；书本装饰使用系统图标替代生成稿中的定制插画。
- 文案：日期、进度、来源数量和相关来源标题均采用语义化本地化键，并补齐项目现有 8 种语言。

## 迭代记录

1. 第一轮截图发现日期重复显示年份并折成两行，属于 P2：破坏首屏信息节奏。
2. 将日期改为语义化的本地化范围格式后重新构建、截图并对照，日期恢复为单行。
3. 最终保留的 P3 差异：头图区使用直边而非波浪边；使用原生书本图标而非定制插画；不重复增加“接下来”提示卡。这些调整符合原生 iOS 组件、信息简洁性和当前产品结构，不影响核心视觉方向。

## 功能验证

- App 构建通过。
- 国际化检查 `npm run lint:i18n` 通过。
- UI 测试 `testWeeklyTopicsCanSwitchFocusedTopic` 通过：点击第 2 个后续选题后，焦点标题正确更新。

---

# 首页周报原位展开与品牌图标调整

**对照目标**

- 视觉基准：`/Users/luwenting/.codex/generated_images/019fc137-2fce-76b2-ac20-b6b3a827578c/exec-547600b7-095a-4809-8fe8-8e8f9f65f52f.png`，并叠加用户本轮明确提出的层级和交互调整。
- 默认展开实现：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-accordion-v1.png`
- 第 2 个选题原位展开：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-accordion-topic-2.png`
- 全页视觉对照：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-accordion-comparison.png`
- 交互状态对照：`/Users/luwenting/.codex/visualizations/2026/08/02/019fc137-2fce-76b2-ac20-b6b3a827578c/weekly-topics-accordion-interaction-comparison.png`
- 设备与状态：iPhone 16 Pro、iOS 18.6、简体中文、浅色模式；分别检查第 1 个和第 2 个选题展开状态。
- 源图：853 × 1844 px；实现：1206 × 2622 px（@3x，对应 402 × 874 pt）。全页对照将实现等比归一到 1844 px 高，归一后宽度约 848 px。

**检查结果**

- 没有可执行的 P0、P1 或 P2 问题。
- 字体与层级：素材数与选题数成为 30 pt 大标题；日期降为 15 pt 次要信息；选题标题统一为 20 pt 半粗体。
- 间距与布局：四个选题使用同一套行结构；展开内容始终出现在当前标题下方，不再移动到页面顶部，也不会替换已展开的其他选题。
- 颜色与图标：YouTube、TikTok、Instagram 使用 Simple Icons 矢量品牌标志，并分别使用红、黑、玫红品牌色；普通笔记继续使用产品青绿色图标。
- 图片质量：三个品牌 SVG 均以矢量形式进入 Asset Catalog，开启矢量保留与模板渲染，在 @3x 截图中边缘清晰。
- 文案：复用现有语义化周报标题和日期键；新增“收起相关来源”语义化无障碍提示，并补齐 8 种语言。
- [P3] 顶部继续使用原生书本符号，而非生成稿中的定制打开书本插画；这是此前已接受的原生实现差异。

**迭代历史**

1. 调整前实现将日期作为主标题，并把点击后的选题搬到顶部焦点区域。
2. 调整后将摘要数据设为主标题，日期降级；所有选题改为原位展开的独立手风琴行。
3. 默认与第 2 个选题展开状态已并排检查，标题位置和内容归属清晰；YouTube 与 TikTok 品牌标志均在真实模拟器中确认。

**验证清单**

- [x] App 构建通过。
- [x] `npm run lint:i18n` 通过。
- [x] UI 测试 `testWeeklyTopicsExpandInPlace` 通过，确认展开第 2 个选题后，第 1 个选题的内容仍然存在。
- [x] 原图、默认实现和展开状态均已打开并并排比较。

final result: passed

---

# 首页空状态 — 方案 1

**对照目标**

- 视觉基准：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-09/source-option-1.png`
- 实现截图：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-09/implementation-option-1-drafts.jpg`
- 全页并排对照：`/Users/luwenting/development/ChillNote/audit/home-empty-state-2026-08-09/option-1-comparison.png`
- 视口与状态：iPhone 16 Pro、iOS 18.6、浅色模式、英文 Drafts 空状态，368 × 800 px。
- 尺寸归一：源图 853 × 1844 px 等比缩放并补边为 368 × 800 px；实现截图为 368 × 800 px。

**检查结果**

- 没有仍需处理的 P0、P1 或 P2 差异。
- 字体与排版：标题使用应用现有半粗体标题令牌，正文使用灰色 callout；字号、换行和居中层级与视觉基准接近。
- 间距与布局：移除方案 3 的卡片和按钮后，112 pt 圆形图标与两段文案在内容区中部形成与基准一致的纵向节奏。
- 颜色与令牌：使用现有品牌蓝、浅蓝强调背景、主文字和次要文字颜色；没有引入新的全局样式。
- 图标与素材：使用对应栏目的原生 SF Symbol，保持清晰和无障碍；[P3] 原生图标笔触与生成稿的定制图标略有差异。
- 文案与内容：Inbox、Drafts、Published、Trash 继续使用各自的语义化多语言文案；方案 3 专属按钮文案已移除。
- 不需要额外局部对照：空状态的图标、标题与正文在全页并排图中均清晰可辨。

**迭代历史**

1. 第一轮实现的标题为 22 pt，且图标到标题的间距为 32 pt，比视觉基准更重、更松，记录为 P2。
2. 标题改用 17 pt 半粗体设计令牌，主间距收紧至 24 pt。
3. 第二轮截图确认图标尺寸、标题层级、正文换行和整体纵向位置均与基准接近。

**验证清单**

- [x] 同步和首次加载期间继续显示骨架屏。
- [x] Inbox、Drafts、Published 切换保持可用，空状态不会出现方案 3 的跳转按钮。
- [x] `npm run lint:i18n` 通过。
- [x] iPhone 16 Pro 模拟器构建与运行通过。

final result: passed

---

# 首页首次视频引导卡片 — 选定方案

**对照目标**

- 视觉基准：`/Users/luwenting/.codex/generated_images/019fe512-8413-7b10-9cd8-816fd2b41a84/exec-880872ed-5d6f-4f8a-8978-b461289ef421.png`
- 最终实现截图：`/Users/luwenting/.codex/visualizations/2026/08/09/019fe512-8413-7b10-9cd8-816fd2b41a84/first-action-guide/05-selected-card-implementation.jpg`
- 完整并排对照：`/Users/luwenting/.codex/visualizations/2026/08/09/019fe512-8413-7b10-9cd8-816fd2b41a84/first-action-guide/04-selected-card-comparison.jpg`
- 设备与状态：iPhone 16 Pro、iOS 18.6、简体中文、浅色模式、Inbox 空状态，首次视频引导卡片可见。
- 尺寸归一：源图 853 × 1844 px 等比缩放至约 370 × 800 px；实现截图为 368 × 800 px。

**检查结果**

- 没有仍需处理的 P0、P1 或 P2 差异。
- 卡片使用完全不透明的暖白底、细暖灰边框和轻阴影，去掉了原方案中过多的品牌蓝。
- 两步操作使用真实 SF Symbols：暖金色分享图标与黑色归档图标，中间以短连接线建立顺序关系。
- 主按钮改为黑色描边、白底和黑字，仅保留箭头提示前进；卡片内部没有蓝色按钮或蓝色大面积背景。
- [P3] 实现保留真实 iOS 状态栏与应用底部工具栏，视觉稿的系统区域比例略有不同。
- [P3] 简体中文文案的自然宽度与英文视觉稿不同；按钮高度保留至少 44 pt，以保证真实点按区域。

**迭代与交互验证**

1. 第一轮预览仍处于 Drafts 状态，卡片纵向略高，关闭按钮带圆形背景，与选定方案存在可见差异。
2. 预览改为 Inbox；收紧卡片间距和上下内边距；关闭按钮改为无底色样式。
3. 最终完整并排对照确认卡片层级、两步顺序、暖白表面和描边按钮均与选定方案一致。
4. 模拟器无障碍快照识别到“跳过”和“知道了”操作；点击“知道了”后卡片正确消失。
5. 卡片内容在完整 368 × 800 对照中清晰可读，因此不需要额外局部裁切。

**验证清单**

- [x] iPhone 16 Pro 模拟器构建通过。
- [x] 新增及修改文案覆盖项目现有 8 种语言。
- [x] “知道了”按钮的关闭交互通过模拟器验证。
- [x] 视觉基准与真实实现已并排比较。

final result: passed
