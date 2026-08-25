# Android Instructions

- Android 客户端使用 Kotlin 与 Jetpack Compose，源码位于 `android/app/src/`。
- 当前产品名和 Kotlin 包名使用 ChillScript / `com.sponteoai.chillscript`。
- 用户可见文案放在 Android string resources 中，不要在 Compose 界面硬编码展示文本。
- 修改英文词条时检查项目现有全部语言资源，并运行本地化校验脚本。
- iOS 是产品行为的重要参考，但 Android 应遵循 Android 原生权限、后台任务、分享、Billing 和导航规则。
- 不要修改 application ID、Google Play 商品 ID、签名配置或 OAuth 回调，除非用户明确要求并接受迁移影响。

## Verification

```bash
cd android
./gradlew testDebugUnitTest
./gradlew assembleDebug
python3 scripts/validate_localizations.py
```
