# ChillScript Repository Instructions

## General

- 除了必要的专业术语，默认使用中文回复。
- 用户是代码初学者。解释问题时说明关键原因、影响和验证结果，不只给结论。
- 当前产品名是 **ChillScript**。`ChillNote` / `chillnote` 只应作为历史技术标识保留，不要新增用户可见的旧品牌文案。
- 开始跨端或架构任务前，先阅读 `docs/PROJECT_CONTEXT.md`。

## Repository Boundaries

- `ios/`：iOS、Widget、分享扩展及 Xcode 工程。
- `android/`：Android / Google Play 原生客户端。
- `server/`：iOS 和 Android 共用的后端、同步、AI、推送与订阅服务。
- `website/`：只维护公开官网、价格、隐私政策、服务条款和账号删除说明；不提供登录后的 Web App。
- `store/`：App Store、Google Play、ASO、商店素材和上传工具；`store/app-store/` 是被主仓库忽略的独立 Git 工作区。
- 删除网页功能时，不得据此删除移动端仍在使用的 `server/` 接口。

## Compatibility Guardrails

- 不要为了品牌统一而修改已发布应用使用的 Bundle ID、Android application ID、App Group、Keychain Group、商品 ID、数据库字段、迁移历史、URL Scheme 或线上域名。
- 如果任务确实需要修改这些兼容标识，必须先说明迁移影响并取得用户明确确认。
- 工作区可能有用户尚未提交的修改。只改当前任务相关文件，不覆盖或回退其他改动。

## User-visible Copy and i18n

- 只要任务涉及用户可见文案、翻译、`Localizable.xcstrings`、`NSLocalizedString`、`String(localized:)`、`Text("...")`、按钮标题、报错提示、空状态、弹窗或无障碍文案，修改前必须完整阅读 `docs/i18n/I18N_RULES.md`。
- 国际化修改必须遵守该规范；发现旧代码与规范冲突时，优先改到规范要求的写法。
- 修改国际化后优先运行项目已有检查；未运行时必须在最终回复中明确说明。

## Verification

- 只验证本次涉及的平台，除非修改了共享协议或用户明确要求全端验证。
- iOS、Android、后端和官网的具体命令分别记录在各目录的 `AGENTS.md`。
- 最终回复需说明实际运行了哪些检查，以及哪些检查未运行。
