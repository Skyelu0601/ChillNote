# ChillScript Android

原生 Kotlin + Jetpack Compose 客户端。目标是与 iOS ChillScript 保持功能、数据和交互一致。

## 构建

```bash
cd android
./gradlew bundleRelease
```

输出文件：`app/build/outputs/bundle/release/app-release.aab`。

正式上传前需创建上传密钥，并通过本机 `keystore.properties` 配置；不要把密钥或密码提交到 Git。
