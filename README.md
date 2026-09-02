# ChillScript Monorepo

ChillScript 是一款面向创作者的 AI 笔记应用。本仓库同时包含 iOS、Android、共用后端和公开官网。

## 项目结构

- `ios/`：iOS App、Widget、分享扩展、测试和 Xcode 工程。
- `android/`：Android / Google Play 原生客户端。
- `server/`：两端共用的 API、同步、AI、推送与订阅服务。
- `website/`：公开官网、价格页和合规页面，不包含登录后的 Web App。
- `docs/`：产品、平台接入、国际化与合规文档。
- `scripts/`：国际化、资源处理和运维脚本。
- `store/`：App Store、Google Play、ASO、商店截图和上传工具的统一入口。

## 商店发布

- `store/app-store/`：App Store Connect、Fastlane、ASO、Apple Ads、截图和营销资料，是独立的 Git 工作区。
- `store/google-play/`：Google Play 文案、截图、源素材与生成脚本，由主仓库管理。
- `store/Gemfile`：Fastlane 等 Ruby 发布工具的依赖入口。

具体目录和常用命令见 `store/README.md`。本地依赖、构建输出、审查截图和工具状态（例如 `node_modules/`、`dist/`、`.next/`、`.venv*/`、`audit/`、`.codex-audits/`、`.claude/`）均可重新生成，不属于项目源码，完成检查后可以删除。

## 常用命令

### iOS

```bash
xcodebuild -project ios/chillnote.xcodeproj -scheme chillnote -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' build
```

### Android

```bash
cd android
./gradlew assembleDebug
```

### 后端

```bash
cd server
npm ci
npm test
npm run build
```

### 官网

```bash
cd website
npm ci
npm run typecheck
npm run build
```

## 命名说明

当前产品名是 **ChillScript**。仓库中仍有 `chillnote`、`ChillNoteWidget`、`com.sponteoai.chillnote` 等历史技术名称；它们可能与已发布应用、签名、数据共享或线上兼容有关，不应仅为了视觉统一而批量替换。

进一步的产品和架构背景见 `docs/PROJECT_CONTEXT.md`。
