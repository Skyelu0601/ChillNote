# ChillNote Internationalization Rules

这份文档是给人和 AI 一起看的国际化约定。

目标很简单：

1. 不要再把“英文展示文案”直接当 key 用。
2. 所有用户看得见的文案，都尽量走统一、可维护、可复用的语义化 key。
3. 以后改英文文案时，不要顺手把 key 一起改坏。

## 先看哪里

国际化相关代码，优先看这几个地方：

- 词条文件：`chillnote/Resources/Localizable.xcstrings`
- 代码入口：`chillnote/Core/Localization/L10n.swift`
- 校验脚本：`scripts/i18n/lint_i18n.py`
- 规范化脚本：`scripts/i18n/normalize_xcstrings.py`
- 术语表：`docs/i18n/glossary_v1.md`

## 核心原则

### 1. 一律优先使用语义化 key

正确方向：

- `home.empty.title`
- `subscription.upgrade.button`
- `speech_recognizer.error.network`
- `note_detail.header.accessibility.back`

不要再新增这种写法：

- `String(localized: "Upgrade to Pro")`
- `NSLocalizedString("Network Error", comment: "")`
- `Text("Delete Permanently")`
- 把英文句子本身当成 `Localizable.xcstrings` 的 key

原因：

- 英文展示文案会改，但 key 应该稳定。
- 语义化 key 更容易搜索、复用、归类和审查。
- 后面批量治理时，不会被“改了一句英文，翻译全断了”拖住。

### 2. 所有用户可见文案都必须进词条表

下面这些都算“用户可见文案”，都要走国际化：

- 页面标题
- 按钮文字
- 占位文案
- Toast / Banner / Alert / Sheet
- 错误提示
- 空状态文案
- 引导文案
- 无障碍文案，比如 `accessibilityLabel`、`accessibilityHint`

### 3. 固定模板 + 变量，占位不要拼英文句子

优先这样做：

- `L10n.text("export.progress.summary", processedCount, totalCount, percentText)`
- `L10n.text("store.error.purchase_failed", errorMessage)`

不要这样做：

- `"SAVE \(percent)%"`
- `"Recording failed: \(error.localizedDescription)"`
- `"Yesterday \(timeText)"`

原因：

- 拼出来的整句字符串很难稳定翻译。
- 不同语言的词序不同，模板 key 更安全。

### 4. 新代码优先用 `L10n.text(...)`

项目当前统一入口是：

```swift
L10n.text("some.key")
L10n.text("some.key", arg1, arg2)
```

默认优先使用这个入口，不要在新代码里继续扩散：

- `String(localized: "...")`
- `NSLocalizedString("英文原文", comment: "")`

如果某个 SwiftUI API 明确需要 `LocalizedStringKey`，也应该优先传“稳定 key”，不要传英文展示文案。

## 命名规则

### 1. key 要按功能分组

推荐结构：

- `common.*`
- `home.*`
- `onboarding.*`
- `subscription.*`
- `settings.*`
- `note_detail.*`
- `pending_recordings.*`
- `speech_recognizer.*`
- `notes_export.*`
- `agent_recipe.*`

### 2. key 名描述“场景”和“用途”，不要描述英文句子

推荐：

- `home.selection_overlay.select_all`
- `settings.export.failed`
- `ai_consent.action.agree_continue`

不推荐：

- `upgrade_to_pro`
- `delete_this_note_now`
- `network_error_message_1`

### 3. 同一页面尽量同一前缀

比如一个页面叫 `OnboardingView`，优先使用：

- `onboarding.title`
- `onboarding.subtitle`
- `onboarding.permission.microphone_title`

不要一会儿 `intro.*`，一会儿 `welcome.*`，一会儿 `onboarding.*` 混着来。

## 允许保留原样的内容

下面这些通常不需要硬做语义化 key，除非它们后来真的变成了用户文案：

- 符号，比如 `#`、`•`
- 纯技术常量
- 路由片段，比如 `"/\(recipe.id)"`
- 仅用于内部逻辑的 id
- 用户自己输入的内容

注意：

- 如果一个字符串最终会显示给用户，就不要拿“它现在只是临时写法”当理由跳过国际化。

## 修改国际化时的推荐步骤

1. 先判断这是不是用户可见文案。
2. 如果是，就先想一个稳定的语义化 key。
3. 在 `chillnote/Resources/Localizable.xcstrings` 里新增或复用该 key。
4. 在代码里改成 `L10n.text(...)` 或等价的稳定 key 用法。
5. 如果有变量，使用格式化模板，不要在代码里拼整句英文。
6. 检查同一页面有没有类似旧写法，能顺手收口就一起收口。

## 修改时的禁区

- 不要新增“英文原文就是 key”的写法。
- 不要把运行时拼出来的整句英文再拿去做本地化。
- 不要只补 `en`，漏掉项目要求的其他语言。
- 不要让 `Localizable.xcstrings` 里出现 `state=new` 或空值。
- 不要在同一功能里混用两套命名风格。

## 验证要求

改完国际化后，优先做这两个检查：

```bash
npm run lint:i18n
xcodebuild -project chillnote.xcodeproj -scheme chillnote -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' build
```

如果只做了其中一个，要在最终说明里写清楚。
如果两个都没做，也要明确告诉用户。

## 给未来 AI 的直接指令

如果你是后续进入这个仓库的 AI，请默认遵守下面这几条：

1. 只要改到用户可见文案，先读这份文档，再动手。
2. 只新增语义化 key，不新增英文原文 key。
3. 优先复用已有 key；如果复用不了，再新增。
4. 新增 key 时，命名要按功能域分组。
5. 改完后，优先运行 `npm run lint:i18n`。

## 一句话版本

ChillNote 的国际化，从现在开始以“语义化 key + `L10n.text(...)` + `Localizable.xcstrings`”为默认标准，不再接受“英文原文直接当 key”的新增写法。
