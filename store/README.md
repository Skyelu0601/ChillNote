# ChillScript 商店发布工作区

这里集中存放 App Store、Google Play、ASO、商店截图与上传工具。移动客户端源码仍分别保留在 `ios/` 和 `android/`，不要把签名配置或应用工程移入本目录。

## 目录结构

- `app-store/`：独立 Git 工作区，包含 Fastlane、App Store Connect 工具、ASO、Apple Ads、元数据、截图和视频素材。
- `google-play/`：Google Play 商店文案、图片、真实设备截图、生成脚本和预览图。
- `Gemfile`、`Gemfile.lock`：Fastlane 使用的 Ruby 依赖版本。

## App Store

Fastlane 的配置位于 `app-store/fastlane/`。从 App Store 工作区运行时，Bundler 会向上找到本目录的 `Gemfile`：

```bash
cd store
bundle install
cd app-store
bundle exec fastlane ios sync_metadata
bundle exec fastlane ios upload_metadata version:1.2.6
bundle exec fastlane ios upload_screenshots version:1.2.6
```

App Store Connect 查询工具位于 `app-store/asc/`，Apple Ads 工具位于 `app-store/appleads/`，ASO 工具与资料位于 `app-store/respectaso/` 和 App Store 工作区根目录。

App Review 的审核账号与说明位于 `docs/app-store/APP_REVIEW_LOGIN.md`。

`app-store/` 保留自己的 `.git` 和未提交修改，主仓库会忽略整个目录。App Store Connect 私钥、环境变量和一次性兑换码不得提交到主仓库。

## Google Play

- 商店图标与 Feature Graphic：`google-play/assets/`
- 原始设备截图：`google-play/source-captures/`
- 各语言商店截图：`google-play/screenshots/<locale>/`
- 总览预览图：`google-play/screenshots/previews/`
- 截图生成工具：`google-play/scripts/`
- Fastlane Supply 配置：`google-play/fastlane/`

从仓库根目录重新生成截图：

```bash
python3.12 store/google-play/scripts/generate_pixel7_store_screenshots.py
```

Android 上传密钥仍必须保留在 `android/upload-key.jks`，本地签名参数仍位于 `android/keystore.properties`；Gradle 构建直接依赖这些位置，不能为了目录统一而移动。

Google Play 上架步骤、签名说明、Billing 配置、Data Safety 草稿和商店文案统一位于 `google-play/docs/`。

### Google Play Fastlane

先把 Google Play 服务账号 JSON 保存在仓库外，并配置本地 `.env`：

```bash
cd store/google-play
cp .env.example .env
# 编辑 .env，把 GOOGLE_PLAY_JSON_KEY_PATH 改为真实的绝对路径
```

这里必须使用已经在 Play Console 获得权限的服务账号 JSON。常见的 `client_secret_*.apps.googleusercontent.com.json` 是 OAuth 客户端配置，不能作为 Fastlane Supply 凭据。

常用命令：

```bash
# 只做本地目录、文案长度和图片尺寸检查
python3.12 scripts/validate_fastlane_metadata.py

# 只验证服务账号权限，不上传
bundle exec fastlane android validate_credentials

# 上传英文文案、图标和 Feature Graphic
bundle exec fastlane android upload_english_listing version_code:12

# 替换九个语言版本的手机截图
bundle exec fastlane android upload_screenshots version_code:12

# 上传已有的签名 AAB 到 Internal testing，默认保持 Draft
bundle exec fastlane android upload_internal

# 先构建签名 AAB，再上传到 Internal testing
bundle exec fastlane android build_and_upload_internal
```

`version_code` 必须是 Internal testing 轨道上已经存在的版本号。截图上传会替换对应语言的现有手机截图。

### Google Play Production

Production 使用两步式发布，避免误把测试包直接推给全部用户。所有命令都必须显式提供版本号；该版本号必须与 `android/app/build.gradle` 一致。

```bash
# 1. 仅在本地检查版本号、文件新旧和 AAB 签名，不连接 Google Play
bundle exec fastlane android verify_production_aab version_code:7

# 2. 上传到 Production 草稿；不会提交审核，也不会开始 rollout
bundle exec fastlane android upload_production \
  version_code:7 \
  confirm:PRODUCTION-7

# 也可以从正式构建开始，一次完成构建、签名检查和草稿上传
bundle exec fastlane android build_and_upload_production \
  version_code:7 \
  confirm:PRODUCTION-7

# 3. 确认 Play Console 中的包、版本说明和国家/地区无误后，提交正式审核
bundle exec fastlane android submit_production \
  version_code:7 \
  confirm:RELEASE-7
```

安全约束：

- `upload_production` 永远只创建 Production 草稿。
- `submit_production` 才会把现有草稿设为完整发布并送审。
- `submit_production` 固定为 100% rollout；如果 Google 要求去 Console 手动提交其他待审核变更，命令会明确失败，不会悄悄留下“尚未送审”的状态。
- AAB 必须已签名、大小合理，且不得早于 Android 源码或构建配置。
- `confirm` 必须包含目标版本号，防止复制旧命令误发其他版本。
- 如果 Google Play 仍有其他未提交的商店资料或 App content 变更，提交前仍应在 Publishing overview 核对变更范围。
