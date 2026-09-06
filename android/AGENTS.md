# Android Instructions

- Android 客户端使用 Kotlin 与 Jetpack Compose，源码位于 `android/app/src/`。
- 当前产品名和 Kotlin 包名使用 ChillScript / `com.sponteoai.chillscript`。
- 用户可见文案放在 Android string resources 中，不要在 Compose 界面硬编码展示文本。
- 修改英文词条时检查项目现有全部语言资源，并运行本地化校验脚本。
- iOS 是产品行为的重要参考，但 Android 应遵循 Android 原生权限、后台任务、分享、Billing 和导航规则。
- 签名配置和 OAuth 回调变更也需先说明影响并取得用户明确确认。

## Verification

以下命令从 `android/` 运行：

- Kotlin、资源或构建配置变更：`./gradlew assembleDebug`。
- 逻辑变更：`./gradlew testDebugUnitTest`；范围明确时使用 `--tests '完整测试类名'` 运行相关测试。
- 文案或语言配置变更：`python3 scripts/validate_localizations.py`。
- 本地化脚本变更：`python3 -m unittest discover -s scripts -p 'test_*.py'`。

UI、权限或后台行为变更按需在设备或模拟器验证；编译通过不代表这些交互已验证。
