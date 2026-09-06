# ChillScript Repository Instructions

## General

- 除了必要的专业术语，默认使用中文回复。
- 用户是代码初学者。简洁说明结果、关键原因、影响和验证情况。
- 当前产品名是 **ChillScript**。`ChillNote` / `chillnote` 只应作为历史技术标识保留，不要新增用户可见的旧品牌文案。
- 按改动路径读取对应目录的 `AGENTS.md`；跨端或架构任务先读 `docs/PROJECT_CONTEXT.md`，其他文档按需读取。
- 在用户已授权的范围内完成实现与验证；常规、可逆的实现选择自行判断，不为计划或技能中的建议重复请求确认。缺少会改变结果的关键信息时，先推进不依赖答案的工作。
- 技能是任务指导，不扩大用户授权。若其中的要求确实阻塞工作，指出具体文件、原文和影响。

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

- 修改用户可见文案（含翻译、错误提示与无障碍文案）前，完整阅读 `docs/i18n/I18N_RULES.md`。本次涉及的旧写法按规范修正，避免扩展为无关页面的批量治理。

## Verification

- 按各目录 `AGENTS.md` 中的适用条件验证本次改动；共享协议变更还需检查受影响客户端，其他任务不默认全端构建。
- 纯文档和指令改动检查差异、引用与配置格式；行为改动运行相关测试与构建。已有检查通过后，仅在新改动、失败或具体疑点出现时扩大或重复检查。
- 最终说明实际运行的检查、结果与相关未运行项；区分本次引入的问题、已有失败和环境限制。
