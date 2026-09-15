# ChillScript 每日异常巡检 · 2026-09-12

> 后续原因调查更正：`generation_failed` 还会包含用户拒绝 AI 授权，不能把 21 次全部称为技术故障；生产 AI 接口同窗没有观察到 429 或 5xx。详见 [原因调查](investigation.md)。

统计窗口：北京时间 **9 月 11 日 19:45:58 至 9 月 12 日 19:45:58**（UTC 11:45:58 对齐的完整 24 小时）。项目 ChillScript / 596105，组织 sponteoai，US Cloud；项目时区 UTC。

**需要处理：新发现 1 条 iOS 原生崩溃。另有 iOS AI 生成失败影响人数增加、登录错误记录占比上升，需要排查；不能直接认定都是版本回归。** 本次仅检查与保存巡检记录，未修改产品代码、线上配置或发布版本。

## 新崩溃

- [PostHog 崩溃详情](https://us.posthog.com/project/596105/error_tracking/01a0931c-98ba-7600-b634-ebf357a78d2f)：SIGABRT，1 次、1 人、1 会话，active。
- 事件时间：北京时间 **9 月 12 日 08:54:14**；上报版本 **iOS 1.2.15**，系统 18.7.10。
- 使用 environment=production、crash_reporting_schema=1 过滤仍可取得此事件；不是两条 development 烟雾测试问题。
- 符号已解析：RichTextEditorView.swift:160 的 dismantleUIView → :269 的 flushPendingChanges → :319 的 publishSelection → NoteDetailViewModel.editorSelection setter / SwiftUI / abort。
- 对照本地代码，编辑器销毁时确实同步回写选区；**疑似退出或关闭编辑器时的状态更新引发崩溃，尚未现场复现，不作为已确认根因**。
- 本窗口 iOS 1.2.15 有 106 位活跃用户。1 位崩溃用户和 106 位活跃用户只作影响范围参考；崩溃重启补报、版本迁移和覆盖差异使其不能充当完整崩溃率。

## 业务异常与使用量

客户端均限定 production + ios/android。人数采用 PostHog unique users（person-on-events 已开启）；活跃使用 Application Opened。人数跨类型、跨版本可重复，不相加。

| 项目 | 最近 24 小时 | 此前 7 天有数据的部分 | 判断 |
| --- | --- | --- | --- |
| Android 活跃 | 453 人 | 286 人 | 这是单日与多日人数，不能当作同比增长率 |
| iOS 活跃 | 178 人 | 109 人 | 新接入和版本覆盖也影响收数 |
| iOS AI 技术类生成失败 | 21 次 / 15 人；生成开始 152 次 / 54 人 | 5 次 / 3 人；开始 60 次 / 20 人 | 已排除单独记录的额度不足；需检查失败原因 |
| iOS 登录错误记录 | 19 次 / 16 人；登录开始 174 次 / 147 人 | 6 次 / 6 人；开始 123 次 / 92 人 | 统一 provider_error，Google 取消可能混入 |
| Android 购买失败 | 9 次 / 9 人；购买开始 144 次 / 125 人 | 7 次 / 4 人；开始 120 次 / 93 人 | 事件比例约 6.3% 对 5.8%，没有明显恶化依据 |
| iOS 购买失败 | 3 次 / 3 人；开始 66 次 / 60 人 | 0 条观察；开始 38 次 / 32 人 | 仍只有 store_error，无法定位或推断扣款 |
| Android 分享阻碍 | 14 次 / 8 人；入口打开 374 次 / 237 人 | 16 次 / 7 人；打开 326 次 / 128 人 | 新版主要是额度不足，不当作技术失败 |
| iOS 分享阻碍 | 3 次 / 3 人；入口打开 243 次 / 86 人 | 0 条观察；打开 103 次 / 39 人 | 全部为额度不足 |

上表分母已用对应开始/入口事件核对；**未按 run_id、purchase_attempt_id、operation_id 配对去重，事件比例不是严格操作失败率**。AI 失败事件比例约 13.8%，此前 8.3%；上一完整 24 小时为 4/39，约 10.3%。样本较小、使用量明显增加，不能仅凭次数认定显著版本回归。iOS 登录错误事件比例约 10.9%，此前约 4.9%，需要补充原因分类后判定技术问题程度。

iOS AI 失败版本：1.2.15 为 15 次/10 人（开始 78 次），1.2.14 为 6 次/5 人（开始 74 次）。代码只将明确的额度不足另分，其他错误统一 generation_failed，无法从事件确认网络、超时或服务端原因。

iOS 登录：Google 17 次/14 人（开始 128 次），Apple 2 次/2 人（开始 39 次）。1.2.15 共 13 次/11 人，1.2.14 共 6 次/5 人。Google 登录 SDK 抛出的取消和技术错误均进入相同 catch，不能把全部 19 次算技术故障。

Android 分享：1.2.15 的 insufficient_credits 为 10 次/6 人；1.2.14 的 unknown 为 4 次/2 人，旧分类可能混入 HTTP 402，无法追溯比例。Android AI 失败记录 32 次/9 人全部是额度不足。两端录音阻碍共 8 次，均是麦克风权限；录音转写各 6 次开始、6 次完成，未观察到失败。

## 支付 SDK 现在能说明什么

新增 Android 诊断已经在正式事件中出现，均为 RevenueCat purchase 阶段：

| SDK 错误 | 次数 / 人数 | 版本 | 含义 |
| --- | --- | --- | --- |
| PurchaseNotAllowedError | 6 / 6 | 1.2.15: 4；1.2.16: 2 | 设备或账号不允许这次购买；具体限制原因未采集 |
| ProductAlreadyPurchasedError | 1 / 1 | 1.2.15 | 商店认为用户已拥有商品，可检查权益同步/恢复购买 |
| StoreProblemError | 1 / 1 | 1.2.15 | 商店连接或处理异常，需要结合交易记录确认结果 |
| 旧版缺少诊断字段 | 1 / 1 | Android 1.2.14 | 只有 store_error |

iOS 3 条购买失败也缺少上述细分字段。取消购买单独记录：Android 107 次、iOS 42 次，不计为技术失败。客户端 subscription_started 为 Android 19 次、iOS 18 次，可能是试用，不等于实际扣款。

错误含义参考 [RevenueCat 官方错误处理说明](https://www.revenuecat.com/docs/test-and-launch/errors) 与 [SDK PurchaseNotAllowedError 定义](https://sdk.revenuecat.com/android/5.4.1/public/com.revenuecat.purchases/-purchases-error-code/-purchase-not-allowed-error/index.html)。本次未读取用户账单，不对个人是否扣款作结论。

## 发布状态与覆盖

已复核本地发布回执：双端 1.2.15 已提交过商店，1.2.16 后续也已提交，见 [1.2.16 发布记录](../releases/mobile-1.2.16-release.md)；该记录确认各自符号已上传。提交审核不等于确认此刻所有地区均已上架。

当前 iOS 1.2.15 有 106 位 production 活跃用户，1.2.16 为 1 位；这些打开事件的 is_testflight=false、is_sideloaded=false。结合真实 schema=1 崩溃与可读栈，确认 **iOS 新崩溃采集已在实际正式环境生效**。Android 1.2.15/1.2.16 活跃分别 245/136 人，新增购买细分字段与分享额度分类已生效；本次未观察到 production Android 原生崩溃，不能据此认定没有崩溃或已完成正式混淆包端到端崩溃验收。

## 对照时段与监测限制

已查询此前完整 7 天，并逐个查询从 9 月 6 日 11:45:58 UTC 起的五个完整 24 小时时段。SDK 9 月 6 日才接入，之前缺失时段不作为零故障基线；iOS 初期覆盖尤其有限。

| 对照窗口结束日（北京时间 19:45） | Android 活跃 | iOS 活跃 | iOS AI 技术错误 / 开始 | iOS 登录错误 / 开始 |
| --- | --- | --- | --- | --- |
| 9 月 7 日 | 21 | 未观察 | 未观察 | 未观察 |
| 9 月 8 日 | 47 | 12 | 1 / 2 | 1 / 19 |
| 9 月 9 日 | 39 | 11 | 0 / 4 | 0 / 6 |
| 9 月 10 日 | 47 | 30 | 0 / 15 | 3 / 30 |
| 9 月 11 日 | 167 | 67 | 4 / 39 | 2 / 62 |
| 9 月 12 日（本次） | 453 | 178 | 21 / 152 | 19 / 174 |

最近 3 小时两端持续有 Application Opened，未见整体收数中断。iOS 独立视频转写仍有 41 次开始却没有对应结果；Android 为 2 次开始/2 次完成。iOS 缺失结果与 Android 部分分享异步终态缺失是已有观测缺口，未知不能当失败。事件清单中仍未观察 video_transcription_failed、teleprompter_failed，不能将其解释为功能零失败。

RevenueCat 事件清单未观察 rc_billing_issue_event；服务端收数仍有试用开始 39 次、试用取消 11 次、到期 0 次。其 schema 无客户端 environment 属性，本次连接也没有 RevenueCat 集成配置读取工具，故这些是项目范围汇总，**没有重新独立确认它们的正式/沙盒分流，不据此宣称正式账单零问题**。

所有 OOM/ANR、系统终止与 iOS 扩展崩溃仍不保证覆盖。此次没有触发测试崩溃、运行构建或修改产品；线上汇总、异常过滤、调用栈与相关源代码已核对。

## 查询入口

- [AI 技术失败明细](https://us.posthog.com/project/596105/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22breakdownFilter%22%3A%7B%22breakdown_limit%22%3A5%2C%22breakdowns%22%3A%5B%7B%22property%22%3A%22platform%22%2C%22type%22%3A%22event%22%7D%5D%7D%2C%22dateRange%22%3A%7B%22date_from%22%3A%222026-09-11T11%3A45%3A58Z%22%2C%22date_to%22%3A%222026-09-12T11%3A45%3A58Z%22%7D%2C%22filterTestAccounts%22%3Afalse%2C%22interval%22%3A%22day%22%2C%22kind%22%3A%22TrendsQuery%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22environment%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22production%22%7D%2C%7B%22key%22%3A%22platform%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%5B%22ios%22%2C%22android%22%5D%7D%5D%2C%22series%22%3A%5B%7B%22event%22%3A%22skill_run_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22error_code%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22generation_failed%22%7D%5D%7D%2C%7B%22event%22%3A%22skill_run_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22error_code%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22generation_failed%22%7D%5D%7D%5D%2C%22trendsFilter%22%3A%7B%22aggregationAxisFormat%22%3A%22numeric%22%2C%22display%22%3A%22ActionsTable%22%2C%22metricColorByDirection%22%3Afalse%2C%22metricShowChange%22%3Atrue%2C%22metricSummary%22%3A%22total%22%2C%22showAlertThresholdLines%22%3Afalse%2C%22showLabelsOnSeries%22%3Afalse%2C%22showLegend%22%3Afalse%2C%22showMultipleYAxes%22%3Afalse%2C%22showPercentStackView%22%3Afalse%2C%22showValuesOnSeries%22%3Afalse%2C%22smoothingIntervals%22%3A1%2C%22yAxisScaleType%22%3A%22linear%22%7D%7D%7D)
- [登录提供方对照](https://us.posthog.com/project/596105/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22breakdownFilter%22%3A%7B%22breakdown_limit%22%3A10%2C%22breakdowns%22%3A%5B%7B%22property%22%3A%22platform%22%2C%22type%22%3A%22event%22%7D%2C%7B%22property%22%3A%22provider%22%2C%22type%22%3A%22event%22%7D%5D%7D%2C%22dateRange%22%3A%7B%22date_from%22%3A%222026-09-11T11%3A45%3A58Z%22%2C%22date_to%22%3A%222026-09-12T11%3A45%3A58Z%22%7D%2C%22filterTestAccounts%22%3Afalse%2C%22interval%22%3A%22day%22%2C%22kind%22%3A%22TrendsQuery%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22environment%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22production%22%7D%2C%7B%22key%22%3A%22platform%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%5B%22ios%22%2C%22android%22%5D%7D%5D%2C%22series%22%3A%5B%7B%22event%22%3A%22login_started%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22login_started%22%7D%2C%7B%22event%22%3A%22login_started%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22login_started%22%7D%2C%7B%22event%22%3A%22login_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22login_failed%22%7D%2C%7B%22event%22%3A%22login_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22login_failed%22%7D%2C%7B%22event%22%3A%22login_completed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22login_completed%22%7D%2C%7B%22event%22%3A%22login_completed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22login_completed%22%7D%5D%2C%22trendsFilter%22%3A%7B%22aggregationAxisFormat%22%3A%22numeric%22%2C%22display%22%3A%22ActionsTable%22%2C%22metricColorByDirection%22%3Afalse%2C%22metricShowChange%22%3Atrue%2C%22metricSummary%22%3A%22total%22%2C%22showAlertThresholdLines%22%3Afalse%2C%22showLabelsOnSeries%22%3Afalse%2C%22showLegend%22%3Afalse%2C%22showMultipleYAxes%22%3Afalse%2C%22showPercentStackView%22%3Afalse%2C%22showValuesOnSeries%22%3Afalse%2C%22smoothingIntervals%22%3A1%2C%22yAxisScaleType%22%3A%22linear%22%7D%7D%7D)
- [支付 SDK 错误与版本](https://us.posthog.com/project/596105/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22breakdownFilter%22%3A%7B%22breakdown_limit%22%3A30%2C%22breakdowns%22%3A%5B%7B%22property%22%3A%22platform%22%2C%22type%22%3A%22event%22%7D%2C%7B%22property%22%3A%22%24app_version%22%2C%22type%22%3A%22event%22%7D%2C%7B%22property%22%3A%22billing_error_code%22%2C%22type%22%3A%22event%22%7D%5D%7D%2C%22dateRange%22%3A%7B%22date_from%22%3A%222026-09-11T11%3A45%3A58Z%22%2C%22date_to%22%3A%222026-09-12T11%3A45%3A58Z%22%7D%2C%22filterTestAccounts%22%3Afalse%2C%22interval%22%3A%22day%22%2C%22kind%22%3A%22TrendsQuery%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22environment%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22production%22%7D%2C%7B%22key%22%3A%22platform%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%5B%22ios%22%2C%22android%22%5D%7D%5D%2C%22series%22%3A%5B%7B%22event%22%3A%22purchase_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%7D%2C%7B%22event%22%3A%22purchase_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%7D%5D%2C%22trendsFilter%22%3A%7B%22aggregationAxisFormat%22%3A%22numeric%22%2C%22display%22%3A%22ActionsTable%22%2C%22metricColorByDirection%22%3Afalse%2C%22metricShowChange%22%3Atrue%2C%22metricSummary%22%3A%22total%22%2C%22showAlertThresholdLines%22%3Afalse%2C%22showLabelsOnSeries%22%3Afalse%2C%22showLegend%22%3Afalse%2C%22showMultipleYAxes%22%3Afalse%2C%22showPercentStackView%22%3Afalse%2C%22showValuesOnSeries%22%3Afalse%2C%22smoothingIntervals%22%3A1%2C%22yAxisScaleType%22%3A%22linear%22%7D%7D%7D)
- [所有业务错误与版本](https://us.posthog.com/project/596105/insights/new#q=%7B%22kind%22%3A%22InsightVizNode%22%2C%22source%22%3A%7B%22breakdownFilter%22%3A%7B%22breakdown_limit%22%3A100%2C%22breakdowns%22%3A%5B%7B%22property%22%3A%22platform%22%2C%22type%22%3A%22event%22%7D%2C%7B%22property%22%3A%22%24app_version%22%2C%22type%22%3A%22event%22%7D%2C%7B%22property%22%3A%22error_code%22%2C%22type%22%3A%22event%22%7D%5D%7D%2C%22dateRange%22%3A%7B%22date_from%22%3A%222026-09-11T11%3A45%3A58Z%22%2C%22date_to%22%3A%222026-09-12T11%3A45%3A58Z%22%7D%2C%22filterTestAccounts%22%3Afalse%2C%22interval%22%3A%22day%22%2C%22kind%22%3A%22TrendsQuery%22%2C%22properties%22%3A%5B%7B%22key%22%3A%22environment%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%22production%22%7D%2C%7B%22key%22%3A%22platform%22%2C%22operator%22%3A%22exact%22%2C%22type%22%3A%22event%22%2C%22value%22%3A%5B%22ios%22%2C%22android%22%5D%7D%5D%2C%22series%22%3A%5B%7B%22event%22%3A%22purchase_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22purchase_failed%22%7D%2C%7B%22event%22%3A%22purchase_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22purchase_failed%22%7D%2C%7B%22event%22%3A%22share_import_blocked%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22share_import_blocked%22%7D%2C%7B%22event%22%3A%22share_import_blocked%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22share_import_blocked%22%7D%2C%7B%22event%22%3A%22skill_run_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22skill_run_failed%22%7D%2C%7B%22event%22%3A%22skill_run_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22skill_run_failed%22%7D%2C%7B%22event%22%3A%22login_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22login_failed%22%7D%2C%7B%22event%22%3A%22login_failed%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22login_failed%22%7D%2C%7B%22event%22%3A%22recording_blocked%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22total%22%2C%22name%22%3A%22recording_blocked%22%7D%2C%7B%22event%22%3A%22recording_blocked%22%2C%22kind%22%3A%22EventsNode%22%2C%22math%22%3A%22dau%22%2C%22name%22%3A%22recording_blocked%22%7D%5D%2C%22trendsFilter%22%3A%7B%22aggregationAxisFormat%22%3A%22numeric%22%2C%22display%22%3A%22ActionsTable%22%2C%22metricColorByDirection%22%3Afalse%2C%22metricShowChange%22%3Atrue%2C%22metricSummary%22%3A%22total%22%2C%22showAlertThresholdLines%22%3Afalse%2C%22showLabelsOnSeries%22%3Afalse%2C%22showLegend%22%3Afalse%2C%22showMultipleYAxes%22%3Afalse%2C%22showPercentStackView%22%3Afalse%2C%22showValuesOnSeries%22%3Afalse%2C%22smoothingIntervals%22%3A1%2C%22yAxisScaleType%22%3A%22linear%22%7D%7D%7D)

