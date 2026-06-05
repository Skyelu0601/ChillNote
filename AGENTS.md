## General

- 除了必要的专业术语，默认请用中文回复我。
- 我是代码小白。解释问题时请尽量通俗，不要只给结论，要把关键原因讲明白。

## Required Reading

- 只要任务涉及用户可见文案、翻译、`Localizable.xcstrings`、`NSLocalizedString`、`String(localized:)`、`Text("...")`、按钮标题、报错提示、空状态、弹窗、无障碍文案，开始修改前都必须先阅读：
  - [docs/i18n/I18N_RULES.md](/Users/luwenting/development/ChillNote/docs/i18n/I18N_RULES.md)

## i18n Guardrail

- 国际化相关修改必须遵守 [docs/i18n/I18N_RULES.md](/Users/luwenting/development/ChillNote/docs/i18n/I18N_RULES.md)。
- 如果发现当前代码和规范冲突，优先把代码改到规范上，而不是沿用旧写法。
- 新增或修改国际化后，优先运行项目已有检查；如果当前任务不方便运行，也要在最终回复里明确说明没有验证。

## Verification

- 只要任务修改了 iOS App 代码，收尾时优先调用 Xcode 对 iPhone 16 Pro Simulator 进行 build：
  - `xcodebuild -project chillnote.xcodeproj -scheme chillnote -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
