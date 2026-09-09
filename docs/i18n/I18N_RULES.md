# ChillScript Internationalization Rules

修改用户可见文案前完整阅读本文件。适用于标题、按钮、占位文案、通知、错误、空状态、引导及无障碍文案；技术常量、路由、内部 ID、符号和用户输入通常无需翻译。

## 统一约定

- 使用稳定的语义化 key，按功能和用途命名，如 `home.empty.title`、`settings.export.failed`、`note_detail.header.accessibility.back`。同一页面使用一致前缀，先复用已有 key；修改英文不改 key。
- 所有展示文案进入对应平台的词条资源，不新增硬编码英文或以英文原文为 key 的写法。
- 动态内容用带变量的完整模板，保留占位符与复数规则，避免拼接句子；不同语言可能需要不同语序。
- 补齐该平台要求的全部语言，不只补英语；翻译不得为空，iOS 词条不得留在 `state=new`。
- 本次改到的旧写法按规范修正；无关页面的历史问题另行记录，不自动扩大为全库治理。

## iOS

- 词条：[Localizable.xcstrings](../../ios/chillnote/Resources/Localizable.xcstrings)。
- 统一入口：[L10n.swift](../../ios/chillnote/Core/Localization/L10n.swift)。新代码使用 `L10n.text(...)`，不另建一套入口。
- SwiftUI API 确实要求 `LocalizedStringKey` 时传稳定 key；不新增 `String(localized: "Upgrade to Pro")`、`NSLocalizedString("Network Error", ...)` 或 `Text("Delete Permanently")` 这类英文原文用法。
- 模板示例：`L10n.text("export.progress.summary", processedCount, totalCount, percentText)`。不要拼接 `"SAVE \(percent)%"` 等英文句子。
- 权限描述同时维护对应的 `InfoPlist.strings`。
- 葡萄牙语同时维护 `pt-BR`（巴西）与 `pt-PT`（葡萄牙），不要只补其中一种。
- 校验器：[lint_i18n.py](../../scripts/i18n/lint_i18n.py)；仅在词条整理任务需要时使用 [normalize_xcstrings.py](../../scripts/i18n/normalize_xcstrings.py)，避免顺带批量重写词条。

## Android

- 词条位于 `android/app/src/main/res/values*/strings.xml`，使用稳定的资源名及 `stringResource` / `getString`，不把 iOS 的 Swift 入口用于 Android。
- 修改基础词条时检查全部现有语言资源；数量文案使用对应复数资源。
- 葡萄牙语通用资源 `values-pt` 使用巴西葡语，`values-pt-rPT` 使用葡萄牙葡语；系统语言声明分别为 `pt`、`pt-PT`，商店分别为 `pt-BR`、`pt-PT`。
- 语言完整性、占位符和声明检查由 [validate_localizations.py](../../android/scripts/validate_localizations.py) 维护。

其他平台沿用自身已有文案与本地化机制；不因本规范引入 iOS 依赖。术语选择参考 [glossary_v1.md](glossary_v1.md)。

## 验证

按 [iOS 指令](../../ios/AGENTS.md)、[Android 指令](../../android/AGENTS.md) 或 [官网指令](../../website/AGENTS.md) 的变更条件选择检查。只验证受影响平台；跨端词条或共享规则变更运行两端本地化校验。最终说明实际检查结果与相关未运行项。
