# Google Play 上传签名

正式发布使用 Google Play App Signing。开发者本地持有的是“上传密钥”，Google Play 保存并使用真正的“应用签名密钥”。

## 当前项目行为

- 没有配置上传密钥时，`bundleRelease` 仍可生成未签名 AAB，方便持续运行构建检查。
- 配置完整的上传密钥后，同一个任务会自动生成已签名 AAB。
- 密钥文件和 `keystore.properties` 已被 `android/.gitignore` 排除，不能提交到 Git。

## 文件配置方式

1. 把上传密钥放到 `android/upload-key.jks`。
2. 复制 `android/keystore.properties.example` 为 `android/keystore.properties`。
3. 填入真实密码和别名。
4. 运行：

```text
cd android
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
