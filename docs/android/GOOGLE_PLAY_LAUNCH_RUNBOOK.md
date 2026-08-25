# ChillScript Google Play 上架步骤

这份清单按实际依赖顺序排列。不要跳过签名、Internal testing 或真实购买验证。

## 第 1 步：商店品牌素材（已完成）

- [x] 512 × 512 PNG 图标：蓝底、白色闪电，已适配圆形和圆角遮罩
- [x] 1024 × 500 PNG Feature Graphic：白底、蓝色 App 图标和 `ChillScript` 字标
- [x] 两张图片均无透明层，尺寸和文件格式合格
- [ ] 最终候选包可运行后，拍摄并排版至少 4 张 1080 × 1920 的真实 Android 截图

正式文件：

- `android/play-store/assets/app-icon-512.png`
- `android/play-store/assets/feature-graphic-1024x500.png`
- `android/play-store/screenshots/android/en-US/`

## 第 2 步：创建并保管上传密钥（需要你操作）

原因：私钥和密码必须只由应用所有者掌握，不能交给 AI，也不能提交到 Git。

1. 按 `docs/android/GOOGLE_PLAY_SIGNING.md` 创建 `android/upload-key.jks`。
2. 创建未提交的 `android/keystore.properties`。
3. 把密码和密钥的加密备份至少保存两份。
4. 在 Play Console 创建应用时启用 **Google Play App Signing**。

## 第 3 步：生成最终候选包（Codex 可继续完成）

签名配置完成后，在 `android/` 目录运行：

```text
./gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
./gradlew verifyReleaseSigning
./gradlew bundleRelease
jarsigner -verify -verbose -certs app/build/outputs/bundle/release/app-release.aab
```

合格标准：所有任务成功，并且最后一条明确显示 AAB 已签名。仓库之前遗留的未签名旧包已经改名为 `app-release-unsigned-stale-DO-NOT-UPLOAD.aab`，禁止上传。

## 第 4 步：创建 Internal testing 版本（需要你操作）

1. 在 Play Console 创建应用，包名必须确认是 `com.sponteoai.chillscript`。
2. 上传第 3 步生成的已签名 `app-release.aab`。
3. 如果任何测试轨道以前使用过 `versionCode = 1`，先把项目的 `versionCode` 增加到未使用过的数字。
4. 添加测试人员，不要直接发布到 Production。

## 第 5 步：配置登录与推送（需要你操作，Codex 可核对）

- Google 登录：给 Android OAuth Client 登记 Play App Signing SHA-1；测试时也登记 upload/debug SHA-1。
- Apple 登录：按 `docs/android/APPLE_OAUTH_SETUP.md` 部署 `assetlinks.json`、添加 Supabase HTTPS callback，再切换生产回调。
- Firebase：按 `docs/android/FIREBASE_PUSH_SETUP.md` 配置 Android App、FCM 和四个客户端环境变量。
- 给审核人员准备可重复使用的登录方式；动态 OTP 不能成为审核阻碍。

## 第 6 步：配置订阅与服务端（需要你操作，Codex 可核对）

1. 在 Play Console 创建：
   - `com.chillnote.pro.monthly`
   - `com.chillnote.pro.yearly`
2. 配置基础方案、地区、价格以及准确的 7 天试用。
3. 给服务账号最小必要的订阅读取与确认权限。
4. 部署 Prisma migrations，尤其是账号删除级联和 `GooglePlayPurchase` 状态表。
5. 按 `server/GOOGLE_PLAY_BILLING.md` 配置 RTDN、Pub/Sub、消息去重、退款/撤销/暂停权益对账。

在 RTDN 和对账完成前，不要公开开启收费版本。

## 第 7 步：真机验收（Codex 可提供逐项测试表）

至少覆盖：

- 邮箱、Google、Apple 登录和退出
- 购买、恢复、取消、退款、暂停和试用资格
- 分享链接、语音录制、待处理录音、相机、提词器和视频导出
- 推送、周选题、小组件、快捷设置按钮
- Android 8、当前主流版本、Android 16
- TalkBack、130% 大字体、深色模式、无网络和低存储

## 第 8 步：拍摄正式截图（Codex 可排版）

1. 只使用第 3 步的最终候选包。
2. 统一浅色模式、同一台设备和真实示例内容。
3. 原始截图先与同状态 iOS 页面并排核对。
4. 最终上传图统一为 1080 × 1920，优先展示 Home、Creator Skills、Note/Editor、Teleprompter 和 Weekly Topics。

## 第 9 步：完成 Play Console 表单（需要你操作）

- App access
- 隐私政策 URL
- Data Safety
- 账号删除 URL
- Ads 声明
- 目标受众与内容分级
- 联系邮箱
- 商店标题、短描述、完整描述和本地化素材

填写时以 `docs/android/GOOGLE_PLAY_DATA_SAFETY_DRAFT.md` 和
`docs/android/GOOGLE_PLAY_STORE_LISTING.md` 为草稿，但必须根据生产环境真实情况最后确认。

## 第 10 步：提交前最后门禁

- [ ] Internal testing 安装包来自 Play，而不是本地 Debug APK
- [ ] 真实购买和恢复成功
- [ ] 账号删除 App 内、网页和服务端都成功
- [ ] 所有正式截图来自同一个最终候选版本
- [ ] AAB 已签名，`versionCode` 未被使用
- [ ] Production 环境变量、数据库迁移、OAuth、FCM、RTDN 已完成
- [ ] Play Console 预审核没有阻断项
