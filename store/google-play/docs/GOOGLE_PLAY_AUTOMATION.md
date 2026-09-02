# Google Play 自动发布

仓库中的 `Android Google Play release` GitHub Actions 工作流会完成以下步骤：

1. 校验版本号和生产发布确认词。
2. 校验 Android 本地化资源并运行 Release 单元测试。
3. 使用受保护的上传密钥生成签名 AAB。
4. 验证 AAB 签名并上传到指定 Google Play 轨道。
5. 将 AAB 作为 GitHub Actions 产物保留 14 天。

## 首次配置

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 内容 |
| --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `android/upload-key.jks` 的 Base64 内容 |
| `ANDROID_UPLOAD_STORE_PASSWORD` | 上传密钥库密码 |
| `ANDROID_UPLOAD_KEY_ALIAS` | 上传密钥别名 |
| `ANDROID_UPLOAD_KEY_PASSWORD` | 上传密钥密码 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | 有 Google Play 发布权限的服务账号 JSON 全文 |
| `CHILLSCRIPT_REVENUECAT_ANDROID_API_KEY` | RevenueCat Android 公钥 |
| `CHILLSCRIPT_FIREBASE_API_KEY` | Firebase API key（如果生产包使用推送） |
| `CHILLSCRIPT_FIREBASE_APP_ID` | Firebase App ID（如果生产包使用推送） |
| `CHILLSCRIPT_FIREBASE_PROJECT_ID` | Firebase Project ID（如果生产包使用推送） |
| `CHILLSCRIPT_FIREBASE_SENDER_ID` | Firebase Sender ID（如果生产包使用推送） |
| `CHILLSCRIPT_ANDROID_AUTH_REDIRECT_URI` | 自定义登录回调；未配置时使用应用默认值 |

在 macOS 上生成上传密钥的 Base64 文本：

```bash
base64 -i android/upload-key.jks | pbcopy
```

建议在 GitHub 的 **Settings → Environments** 创建：

- `google-play-testing`：内部、Alpha 和 Beta 轨道使用。
- `google-play-production`：Production 使用，并配置 Required reviewers，确保正式发布前需要人工批准。

服务账号需要在 Google Play Console 的 **Users and permissions** 中获得目标应用的发布权限，并为关联的 Google Cloud 项目启用 Google Play Android Developer API。

## 发布一个版本

进入 GitHub 的 **Actions → Android Google Play release → Run workflow**，填写：

- `version_name`：用户看到的版本，例如 `1.3.0`。
- `version_code`：Google Play 从未使用过的递增整数，例如 `9`。
- `track`：首次建议选择 `internal`。
- `release_status`：`completed` 会提交到所选轨道；`draft` 只创建草稿。
- `confirmation`：测试轨道留空。Production 草稿填写 `PRODUCTION-9`；Production 正式发布填写 `RELEASE-9`。

工作流通过 Gradle 参数注入版本号，不会为了发布而改写或提交 `android/app/build.gradle`。正式发布前，先在 Internal testing 安装并验证 Google 登录、Apple 登录、订阅购买、恢复购买、推送和链接/视频导入。

## 安全边界

- 工作流只能手动触发，不会因普通代码 push 意外发布。
- 同一轨道同一时间只运行一个发布任务，后触发的任务不会取消正在上传的版本。
- Production 的草稿和正式发布使用不同确认词。
- 上传密钥和服务账号只从 GitHub Secrets 写入临时目录，不会进入仓库或构建产物。
- Production 环境应启用 GitHub 人工审批；确认词不能替代审批。
