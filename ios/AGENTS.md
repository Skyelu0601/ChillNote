# iOS Instructions

- iOS 主源码位于 `ios/chillnote/`，测试位于 `ios/chillnoteTests/` 和 `ios/chillnoteUITests/`。
- Widget 与分享扩展分别位于 `ios/ChillNoteWidget/` 和 `ios/ChillNoteShareExtension/`。
- 工程与 Scheme 名 `chillnote` 是历史技术标识；签名能力变更也需先说明影响并取得用户明确确认。
- 新代码优先沿用现有架构和 `L10n.text(...)`，不要额外引入第二套本地化入口。

## Verification

以下命令从仓库根目录运行：

- 文案、SwiftUI 展示代码或权限描述变更：`python3 scripts/i18n/lint_i18n.py`。
- Swift、资源或工程变更：`xcodebuild -project ios/chillnote.xcodeproj -scheme chillnote -destination 'generic/platform=iOS Simulator' build`。
- 逻辑修复运行相关单元测试；交互变更按需在模拟器验证。用 `xcodebuild -project ios/chillnote.xcodeproj -scheme chillnote -showdestinations` 选择本机可用设备，执行 `test` 时用具体设备 ID 和 `-only-testing:` 限定相关测试。通用模拟器构建只验证编译，不代表运行或测试通过。
