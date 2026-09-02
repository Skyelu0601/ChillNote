# ChillScript Project Context

## Product

ChillScript 是面向创作者的 AI 笔记应用，帮助用户保存视频、语音和灵感，将来源、描述、Hook 与转录整理成可搜索、可复用的创作素材。

当前产品名是 **ChillScript**。`ChillNote` 是历史名称，只可能继续出现在兼容性技术标识和旧文件名中。

## Supported Clients

ChillScript 当前维护两个原生客户端：

- iOS：位于 `ios/`，包含主 App、Widget、分享扩展与测试。
- Android / Google Play：位于 `android/`，使用 Kotlin 与 Jetpack Compose。

两个客户端应共享产品概念、账号、同步数据和核心功能，但应遵循各平台原生交互和商店规则，不要求逐像素复制。

## Shared Backend

`server/` 是两个移动客户端共同依赖的后端，负责账号相关操作、数据同步、AI 请求、链接导入、推送通知、额度和订阅校验等能力。

后端不是“网页端”。停止维护登录后的 Web App，不代表这些接口可以删除。删除任何接口前必须先检查 iOS 与 Android 调用方。

## Website Scope

`website/` 只作为公开官网，负责：

- 产品介绍和商店下载入口。
- 价格说明。
- 隐私政策和服务条款。
- 账号删除说明。
- 搜索引擎验证和站点地图。

网站不再提供：

- 浏览器登录或注册。
- 网页版笔记、录音、编辑、同步和 AI Skills。
- 网页订阅购买入口。

Android 的 OAuth / App Link 可能继续使用 `www.chillnoteai.com` 域名作为回调基础设施；这与提供 Web App 是两回事。

## Store Operations

`store/` 是 App Store、Google Play、ASO、商店截图和上传工具的统一入口：

- `store/app-store/`：独立 Git 工作区，包含 Fastlane、App Store Connect、ASO、Apple Ads 和 App Store 素材。
- `store/google-play/`：主仓库管理的 Google Play 素材、截图生成工具和上架文档。

Android 上传密钥与签名参数仍保留在 `android/`，因为 Gradle 构建直接依赖这些兼容位置。

## Naming and Compatibility

以下名称是历史兼容标识，除非有完整迁移方案，否则保持不变：

- iOS Bundle ID 与扩展 Bundle ID。
- Android application ID。
- App Group 与 Keychain Group。
- StoreKit 和 Google Play 商品 ID。
- URL Scheme、线上域名、数据库字段与迁移历史。

新增的用户可见文案、文档和产品说明统一使用 **ChillScript**。
