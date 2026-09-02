# Google Play 上传签名

正式发布使用 Google Play App Signing。开发者本地持有的是“上传密钥”，Google Play 保存并使用真正的“应用签名密钥”。

## 当前项目行为

- 没有配置上传密钥时，Debug 构建和检查仍可运行，但 `bundleRelease` / `assembleRelease` 会明确失败，避免误把未签名 AAB 当成候选包。
- 配置完整的上传密钥后，同一个任务会自动生成已签名 AAB。
- 密钥文件和 `keystore.properties` 已被 `android/.gitignore` 排除，不能提交到 Git。

## Google 登录证书登记状态（上架时必查）

- [x] 已在 Google Cloud 创建上传签名版本的 Android OAuth Client。
  - 包名：`com.sponteoai.chillscript`
  - 上传证书 SHA-1：`BD:D9:E5:69:A1:31:D0:1A:BF:6F:9F:EA:42:C6:3C:68:1D:FA:22:34`
  - 2026-08-24 已在 Pixel 7 真机验证 Google 登录成功。
- [ ] 首次上传 AAB 并启用 Google Play App Signing 后，从 Play Console 复制“应用签名证书 SHA-1”。
- [ ] 在 Google Cloud 为同一包名再创建一个 Android OAuth Client，填写 Play App Signing SHA-1；不要删除现有上传签名客户端。
- [ ] 从 Internal testing 安装 Play 分发版本，再次验证 Google 登录。

这里通常不需要修改 App 代码。原因是本地候选包使用上传证书，而 Play 商店分发包使用 Google 的应用签名证书；Google 登录必须分别登记两套 SHA-1。

## 第一次创建上传密钥

这一步必须由应用所有者在自己的电脑上完成，因为密码和私钥不能交给 AI、聊天工具或代码仓库。

1. 打开“终端”，进入项目的 Android 目录：

```text
cd /Users/luwenting/development/chillnote/android
```

2. 运行下面的命令。命令会在终端里交互式询问密码，不会把密码写进命令历史：

```text
keytool -genkeypair -v -keystore upload-key.jks -alias chillscript-upload -keyalg RSA -keysize 4096 -validity 10000
```

3. 把密钥密码立即存入密码管理器，并给 `upload-key.jks` 做一份加密离线备份。

## 文件配置方式

1. 确认上传密钥位于 `android/upload-key.jks`。
2. 复制 `android/keystore.properties.example` 为 `android/keystore.properties`。
3. 填入刚才保存的真实密码；别名保持 `chillscript-upload`。
4. 先验证配置，再生成并校验候选包：

```text
cd android
./gradlew verifyReleaseSigning
./gradlew bundleRelease
jarsigner -verify -verbose -certs app/build/outputs/bundle/release/app-release.aab
```

## CI 环境变量方式

不创建 `keystore.properties`，改用以下四个环境变量：

```text
CHILLSCRIPT_UPLOAD_STORE_FILE=/absolute/path/to/upload-key.jks
CHILLSCRIPT_UPLOAD_STORE_PASSWORD=...
CHILLSCRIPT_UPLOAD_KEY_ALIAS=chillscript-upload
CHILLSCRIPT_UPLOAD_KEY_PASSWORD=...
```

## 安全要求

- 上传密钥、密码和恢复资料至少保存两份，放在受保护的密码管理器或加密备份中。
- 不通过聊天、邮件或 Git 传输私钥。
- 在 Play Console 开启 Google Play App Signing。
- 如果上传密钥遗失，使用 Play Console 的上传密钥重置流程；应用签名密钥不应由日常构建机器持有。
