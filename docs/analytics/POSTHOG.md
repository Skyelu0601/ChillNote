# ChillScript PostHog 接入

## 项目

- 项目：ChillScript，ID `596105`，US Cloud。
- [项目设置](https://us.posthog.com/project/596105/settings/project-details)
- [实时事件](https://us.posthog.com/project/596105/activity/explore)
- iOS：官方 SDK `3.56.0`（Swift Package Manager 精确版本）。
- Android：官方 SDK `3.61.1`（Maven 精确版本）。
- SDK 入口：两端 `ProductAnalytics`，由主应用启动时配置。iOS Widget、分享扩展不初始化。
- RevenueCat：项目 `ChillScript: Content Ideas` 已开启官方 PostHog 集成，Region 为 US，正式事件发送到本项目；Sandbox key 暂未配置，避免测试购买污染正式数据。
- 代码中的 `phc_` token 是允许内置在客户端的公开写入 token；不要替换为个人或管理 API key。

## 已接入事件

| 事件 | 含义 |
| --- | --- |
| `app_session_started` | 每次应用进程启动一次，不代表成功登录或新注册 |
| `Application Installed` | SDK 首次识别安装；已有用户升级到接入版本也可能产生 |
| `Application Updated` | SDK 检测到应用版本变化 |
| `Application Opened` | 应用打开或返回前台 |
| `Application Backgrounded` | 应用进入后台 |
| `$identify` | 登录账号与匿名活动关联 |

业务事件按以下流程接入：

- 激活：`app_first_opened`、引导步骤与完成、主动登录开始/成功/失败。
- 分享转写：分享入口打开、链接接收/阻碍，以及视频转写和成果保存。
- 录音转写：请求、实际开始、停止/取消/阻碍、转写结果和成果保存。
- 创作：用 `creation_completed` 和 `creation_type` 统一统计分享转写、录音转写、AI 采用与提词器视频；按业务操作持久去重。
- 付费：介绍页、价格页、套餐选择、购买开始/取消/失败和订阅成功，使用 `paywall_placement` 区分 `post_login`、`settings` 与 `feature_gate`。
- AI Skill：选择、授权决定、生成开始/成功/阻碍/取消/失败、实际采用；自定义 Skill 只上报 `custom`。
- 提词器：打开、滚动/拍摄开始、停止、视频保存和固定错误类别。
- RevenueCat 服务端：`rc_initial_purchase_event`、`rc_trial_started_event`、`rc_trial_converted_event`、`rc_trial_cancelled_event`、`rc_renewal_event`、`rc_cancellation_event`、`rc_uncancellation_event`、`rc_subscription_paused_event`、`rc_expiration_event`、`rc_billing_issue_event` 与 `rc_product_change_event`。

双端登录 RevenueCat 后设置 `$posthogUserId`，与 PostHog 的小写内部账号 UUID 对齐。发起 RevenueCat 购买前写入 `paywall_placement`、`paywall_view_id` 与 `purchase_attempt_id` 客户属性；RevenueCat 集成已启用“将客户属性作为 PostHog person properties 发送”。客户端事件用于分析付费意图和入口，`rc_*` 事件作为试用、真实扣款、续费、取消、到期与账单问题的服务端事实。

PostHog 已建立并置顶 [ChillScript 产品增长总览](https://us.posthog.com/project/596105/dashboard/2069370)，包括 24 小时激活、每周创作用户、创作留存、引导登录、分享转写、录音转写、AI Skill、双付费入口、提词器、试用转付费、订阅生命周期和订阅收入。客户端图表过滤 `environment = production`；RevenueCat 图表仅接收正式 key 的服务端事件。新业务事件随包含本次代码的商店版本发布后开始产生正式数据。

公共属性：`platform` 为 `ios` / `android`，`environment` 为 `development` / `production`，以及 SDK 提供的系统、设备、版本信息。

初次查看：在实时事件里按 `platform` 分别筛选双端；正式分析加 `environment = production`，排除开发构建。分析日活可用 `Application Opened` 的独立用户数。匿名用户按安装标识计数；登录后使用小写内部账号 UUID，双端同账号归一。退出登录、账号切换时重置 SDK 身份；token 刷新不当成新注册。

## 数据边界

- 不上传笔记、标题、录音、转写、提示词、邮箱、OAuth URL、推送 token 或原始错误信息。
- 禁用自动页面、点击内容、深链和录屏采集；不启用问卷或功能旗标预加载。2026-09-11 起源码启用自动崩溃采集，异常经过字段白名单脱敏，仅保留异常类型、调用栈、符号匹配标识和设备/版本元数据；移除异常原文、breadcrumbs 和局部变量。
- 事件设置 `$geoip_disable = true`，不使用 IP 推断地理位置；PostHog 仍会接收并在事件中保留连接来源 IP；此配置不等于 IP 匿名化。
- iOS PrivacyInfo 已增加分析用途与产品交互声明；官网隐私政策源码已补充 PostHog。发布应用前需同步发布官网政策，并在 App Store / Google Play 隐私表单声明账号/安装标识、产品交互与设备信息的分析用途。
- 账号删除流程不会自动删除 PostHog 历史记录；处理删除请求时须在 PostHog 按内部账号 ID 删除对应用户数据。
- 本次未增加广告追踪或 ATT 权限，也未改变商品、价格、试用或订阅权益。

## 验收

1. 安装开发包并启动，等待约 30 秒或切后台触发批量发送。
2. 在实时事件检查两种 `platform` 的 `app_session_started` 与 `environment = development`。
3. 使用同一测试账号登录双端，检查 distinct ID 都为同一个小写 UUID。
4. 退出后重新打开应用，检查后续事件使用新的匿名 ID；切换账号不能沿用上一账号 ID。
5. 查看事件属性，确认没有笔记内容、邮箱、登录链接或录屏。

参考：[iOS SDK](https://posthog.com/docs/libraries/ios)、[Android SDK](https://posthog.com/docs/libraries/android)。

## 崩溃监测与错误诊断（2026-09-11）

- 两端新增 `$exception` 自动捕获；Android 同时开启系统原生崩溃读取。仅主应用初始化 SDK，iOS 分享扩展与 Widget 不在本次覆盖范围内。
- 崩溃事件带 `crash_reporting_schema = 1`，正式监测必须筛选 `environment = production`。测试崩溃会进入 development，不能计入正式事故。
- Android `purchase_failed` 保留原有 `error_code`，新增 `billing_provider`、`billing_error_code`、`billing_stage`，只记录 SDK 枚举或数值代码。用户取消仍单独记录；这次未改商品、支付流程或权益。
- Android 分享入口把 `ShareLinkInsufficientCreditsException` 分类为 `insufficient_credits`，无有效链接为 `invalid_share_content`。1.2.14 历史 `unknown` 可能混入额度限制，不能全部解释为程序 bug，也不能追溯补齐。
- 新代码必须随下一版发布后才会产生正式崩溃数据；不能补收旧版本未记录的崩溃。iOS PrivacyInfo 和官网隐私政策源码已补充崩溃数据声明，发布时同步检查商店隐私表单。
- 符号上传、验收及覆盖边界见 [CRASH_MONITORING.md](CRASH_MONITORING.md)。

## AI 与登录错误分类（2026-09-12 源码修复）

以下口径以事件 `diagnostic_schema = 2` 为准，必须随包含修复的客户端版本发布后验证正式收数。历史 `generation_failed` / `provider_error` 无法追溯重分类，不能用新版比例回填历史。

| 事件／属性 | 统计口径 |
| --- | --- |
| `ai_consent_prompted` / `ai_consent_accepted` / `ai_consent_declined` | 每个授权弹窗记录一次决定，附 `trigger`、`consent_version`；拒绝不是生成失败 |
| `skill_run_started` | 同意当前版本 AI 数据使用说明后才开始；每次重试使用新的 `run_id` |
| `skill_run_completed` | 已得到可用结果；不代表用户已采用结果 |
| `skill_run_blocked` | 额度不足 `insufficient_credits`、限流 `rate_limited`、登录失效 `authentication_required`、访问被拒 `access_denied`；防御性授权拒绝为 `ai_consent_required` |
| `skill_run_cancelled` | 请求被取消，不能作为技术故障统计 |
| `skill_run_failed` | 网络 `network_error` / `network_timeout`、HTTP `server_error` / `http_error`、响应 `invalid_response`、配置 `invalid_configuration`、未分类 `unknown_error` 等技术错误 |
| iOS `login_cancelled` | Google SDK 的明确取消单独记录 `user_cancelled`；任务取消为 `request_cancelled`，均不再显示登录失败提示 |
| iOS `login_failed` | 区分凭证、展示、Google SDK `provider`、后端 `token_exchange` 与会话阶段；不能将所有旧 `provider_error` 解释为 Google 服务故障 |

AI 新诊断字段包括 `error_category`、`error_stage`、有明确响应时的 `http_status`，以及适用的固定 `sdk_error_domain` 和数值 `sdk_error_code`。不上传 SDK 错误原文、HTTP 响应正文、请求 URL、提示词或笔记。HTTP 403 只表明访问被拒，不等同于用户未同意 AI 数据使用说明；网络错误也不应触发重新授权。

Google 取消判断同时检查 SDK 错误域、返回代码和登录阶段，依据 [Google 官方错误定义](https://developers.google.com/identity/sign-in/ios/reference/Enums/GIDSignInErrorCode)。其他错误域中的同一个数值不能推断为用户取消。

监测时把成功、阻碍、取消、技术失败分列。生成的可比操作分母按同一端／版本／时间范围、`diagnostic_schema = 2` 的 `run_id` 关联开始与终态并去重；仍未结束或跨窗口的操作列为未知，不计为失败。授权拒绝率另用弹窗事件统计，不能并入生成失败率。新旧口径不要直接混算。

客户端行为：拒绝不持久化为永久禁止，下次明确使用 AI 时重新提示；接受当前 `v1` 后跨启动保留，后续网络或额度问题按真实原因处理。连续请求共用一个提示，被取消的请求会移除；旧弹窗的关闭回调不能拒绝后来出现的新弹窗。iOS 翻译在语言选择弹窗真正关闭后才请求 AI 授权。

编辑器修复针对已观测的 `dismantleUIView → flushPendingChanges → publishSelection` 崩溃路径：销毁时取消延迟任务、断开 delegate／工具栏回调，不再访问 SwiftUI 绑定；最后一笔未提交文字交由保留的视图模型暂存，再保存。尚未初始化的编辑器不能清空笔记，过期编辑器也不能覆盖更新后的内容。需在新版本正式使用后继续观察原崩溃问题是否复现，不能仅凭本地测试宣布线上崩溃归零。

## 本次验证（2026-09-06）

- iOS 通用模拟器构建通过；工程和隐私清单格式检查通过。
- Android `assembleDebug` 和 `testDebugUnitTest` 通过：118 项测试，0 失败。
- 官网 `typecheck`、生产构建通过，`/privacy` 页面成功生成。
- iOS 本地化校验通过。
- iOS 和 Android 模拟器开发包已安装并启动。
- PostHog 实时事件页面已确认 6 条真实 SDK 事件：每端各 1 条 `Application Installed`、`app_session_started`、`Application Opened`。两端启动事件均带正确 `platform`、`environment = development` 和 `$geoip_disable = true`，抽查未包含笔记、录音、邮箱或登录链接。
- MCP 事件定义索引存在延迟，本次最终收数证据以 PostHog 实时事件页面为准。
- 未发布商店版本或部署官网；跨端真实账号登录、退出/切换账号的交互验收尚未执行。

## 行为事件扩展验证（2026-09-06）

- iOS 通用模拟器重新构建通过，包含主应用、分享扩展和 Widget。
- Android `assembleDebug` 与 `testDebugUnitTest` 重新通过。
- PostHog 的激活漏斗、趋势和留存查询已先验证查询结构；正式业务事件尚未随商店版本发布，因此 production 当前为 0 属预期结果。
- 看板 ID `2069370` 已置顶，共保存 12 个图表，其中 9 个客户端 production 图表和 3 个 RevenueCat 服务端图表。

## RevenueCat 服务端事件（2026-09-06）

- RevenueCat → PostHog 官方集成已启用，使用默认 `rc_*` 事件名和 Gross revenue 口径。
- 仅配置 Production API key；Sandbox key 留空，因此测试购买不会进入当前正式项目。
- RevenueCat 集成事件列表目前为空；历史订阅变化不会补发，新交易或后续生命周期变化发生后开始收数。
- 双端代码已补齐 `$posthogUserId` 与购买入口属性；需随新版客户端发布后，新的客户属性才会完整写入 RevenueCat。
- 看板已新增“试用转付费漏斗”“订阅生命周期趋势”“订阅收入趋势”。
