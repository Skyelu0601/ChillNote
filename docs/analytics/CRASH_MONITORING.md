# ChillScript 崩溃监测

项目：[ChillScript / 596105](https://us.posthog.com/project/596105/error_tracking)，US Cloud。

## 覆盖范围

iOS 主应用自动捕获未处理异常/致命信号；发生崩溃后需再次打开应用才能发送持久化的报告。连接调试器会拦截崩溃，所以测试时必须脱离调试器。Android 自动捕获未处理 Java/Kotlin 异常，并启用 Android 12+ 的系统原生崩溃报告读取（下一次启动发送）。

这不等于覆盖所有退出：用户强制结束、系统回收、所有 OOM/ANR/卡死和 iOS 扩展崩溃不能据此保证被记录。已处理的购买/导入错误继续使用业务事件。没有 `$exception` 不能证明从未崩溃。

`CrashEventSanitizer` 对事件属性执行白名单，保留类型、栈、版本、构建、设备、会话和符号标识；消息替换成 `[redacted]`，移除任意业务属性、breadcrumbs、局部变量与路径目录。保留既有匿名/账号身份用于统计受影响人数。原生崩溃若跨升级才上传，事件版本可能是重新启动时的版本，定位应结合符号 build ID。

## 发行构建的符号文件

首次安装本地工具：

```sh
npm ci --prefix scripts/analytics
scripts/analytics/node_modules/.bin/posthog-cli --host https://us.posthog.com login
```

登录时选 ChillScript（596105），授权 `error tracking write` 与 `organization read`；不把个人 key 写入客户端或 Git。CI 可通过 `POSTHOG_CLI_API_KEY` 注入凭证；主机/项目在构建配置中固定到本项目。

- Android 官方 Gradle 插件 `1.6.0` 将映射 ID 注入 minified 构建；release 打包后自动上传 R8/ProGuard 映射。当前应用没有自行编译的 NDK 库，依赖附带的 `.so` 已剥离调试信息，因此不启用可选的 native symbol 上传；Java/Kotlin 崩溃仍可通过 R8 映射反混淆。debug 构建无需上传。没有认证时 release 上传会报错，必须在发行前处理；不要使用 `--no-fail` 或 dry-run 掩盖发行上传失败。
- iOS Release 已开启 `dwarf-with-dsym`。共享 Scheme 的 Archive PostAction 在现有 GoMarketMe dSYM 修复之后调用 `scripts/analytics/upload-ios-symbols.sh`，只上传符号，不附带源文件。若 Archive PostAction 上传失败，Xcode 仍可能生成 archive；发行者必须检查上传日志及 PostHog 的 Symbol sets，不能把“归档成功”等同于“符号上传成功”。可用下面命令重试同一个 archive：

```sh
bash scripts/analytics/upload-ios-symbols.sh /path/to/chillnote.xcarchive
```

每次实际发出的二进制必须对应其自己的符号文件；不能拿重编译文件代替旧版符号。iOS 扩展没有启用捕获，上传其符号不代表已经覆盖扩展。

参考：[iOS 安装](https://posthog.com/docs/error-tracking/installation/ios)、[Android 安装](https://posthog.com/docs/error-tracking/installation/android)、[iOS 符号](https://posthog.com/docs/error-tracking/upload-source-maps/ios)、[Android 映射](https://posthog.com/docs/error-tracking/upload-mappings/android)。

## 开发包验收

仅在模拟器和开发包进行。两端均有仅 Debug 可用的崩溃触发入口，正式构建不包含触发代码。

```sh
# iOS：安装后脱离调试器启动，10 秒后崩溃，然后不带参数重启。
xcrun simctl launch booted com.sponteoai.chillnote --posthog-crash-smoke-test
xcrun simctl launch booted com.sponteoai.chillnote

# Android：等待崩溃后再启动主界面。
adb shell am start -n com.sponteoai.chillscript/.analytics.CrashSmokeTestActivity
adb shell am start -n com.sponteoai.chillscript/.MainActivity
```

在 PostHog 检查 `$exception`、`environment = development` 和 `crash_reporting_schema = 1`；确认 fatal、handled=false、调用栈存在，原始消息被替换。查看错误详情并核对上传符号可解析到应用代码。正式看板和每日监测排除这两条测试事件。

## 2026-09-11 代码核查结论

Git 中 `20ac6096..92194d9e` 的 Android billing 与订阅 UI 目录没有差异；版本号从 1.2.11 到 1.2.14 的提交没有修改购买逻辑。此结论基于仓库，未逐个解包核对商店历史二进制。

此前一周记录的 7 次 `purchase_failed`（4 人）是 SDK 返回非取消错误的回调，并统一分类为 `store_error`，无法再区分网络、商店、支付限制或其他原因。该事件不是扣款账本，是否成交应结合 RevenueCat/商店交易记录判断。新增诊断仅对以后事件生效。

1.2.14 添加了 HTTP 402 额度不足处理，但分享入口分类器未覆盖对应异常，落入 `unknown`。此前 10 次分享阻碍（5 人）可能包含额度不足，现有数据不能确认比例。

## 本次实际验收（2026-09-11）

- iOS 通用模拟器构建通过；`CrashEventSanitizerTests` 在 iOS 26.5 模拟器运行 2 项，0 失败。
- Android 最终 `assembleDebug`、`testDebugUnitTest` 通过，125 项测试，0 失败。
- 官网 `typecheck` 与生产构建通过；iOS 本地化、PrivacyInfo 格式、Scheme XML、上传脚本语法和差异检查通过。
- [iOS 测试报告](https://us.posthog.com/project/596105/error_tracking/01a08fbc-a810-7f90-99af-7e5f6ed035ea)：1 次 `SIGTRAP`，消息为 `[redacted]`、fatal、handled=false，成功解析到 `ProductAnalytics.swift:70` 的测试触发函数。
- [Android 测试报告](https://us.posthog.com/project/596105/error_tracking/01a08fbf-e359-7a11-915b-f1b611b5617b)：1 次 `IllegalStateException`，消息为 `[redacted]`、handled=false，调用栈指向 `CrashSmokeTestActivity.kt:13`。本次是未混淆 Debug 包，不构成正式 R8 反混淆验收。
- 通过带 `environment=development`、`crash_reporting_schema=1` 的查询，分别取到上述测试事件；相同时间窗口的 production 错误查询为 0。这个 0 仅证明测试未混入正式数据，不能证明旧版无崩溃。
- 用户已授权官方 CLI 的 `error_tracking:write` 与 `organization:read`，凭证由 CLI 保存到本机；没有把个人 key 放入代码。iOS 测试包 dSYM 已上传，服务器 `has_uploaded_file=true`，ref 为 `4806F21B-E25B-3163-91A9-DB011DF52080`，并已实际解析上面的栈帧。
- Android 正式打包任务包含映射 ID 生成、assets 注入与 ProGuard 映射上传。已校验脚本在 GUI 常见的精简 PATH 下能找到 CLI。当前应用没有可上传的第一方 NDK 调试符号，因此 native 符号上传保持关闭。未构建/上传新正式版本的 R8 映射或正式 iOS archive，下一次发行必须核对各自适用的符号上传成功。
- 未发布 App Store / Google Play 新版本，也未部署官网；iOS 扩展崩溃和 Android NDK 原生崩溃未做现场触发测试。此次实测覆盖 iOS 主应用原生崩溃及 Android 主应用 Java/Kotlin 未处理异常。
