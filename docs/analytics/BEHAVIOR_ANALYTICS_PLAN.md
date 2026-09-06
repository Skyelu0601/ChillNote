# ChillScript 用户行为分析方案

版本：v1 已实施 · 2026-09-06

状态：iOS 与 Android 已接入本文的核心客户端事件，并在 PostHog 建立「ChillScript 产品增长总览」看板。RevenueCat 官方 PostHog 集成已提供权威试用、扣款、续费、取消和到期事件；无需再次打开主应用即可确认的非订阅异步任务结果仍属于后续服务端接入范围。

## 1. 目标与核心指标

围绕七个重点：新用户激活、视频分享转文字、录音转写、持续创作、两个付费入口、AI Skill、提词器。

核心指标：**每周成功完成至少一次创作的独立用户数，以及这些用户之后是否继续创作。**

辅助指标：24 小时首次创作率、分享视频转写成功率、录音转写成功率、7 天再次创作率、首次登录付费页转化率、设置付费页转化率。

“成功创作”指可使用的成果已产生并可靠保存，统一记录 `creation_completed`：

| creation_type | 成功条件 |
| --- | --- |
| video_transcript | 分享或导入的视频已得到非空文字，并保存到用户可访问的内容中 |
| audio_transcript | 录音已得到非空文字，并保存到用户可访问的内容中 |
| ai_applied | 用户主动采用、另存或导出 AI Skill 结果成功；只展示生成结果不算 |
| teleprompter_video | 提词拍摄的最终视频已成功保存或导出 |
| text_note | 用户主动提交的新文本内容成功保存；排除空白笔记、自动保存、示例和后台同步 |

同一业务操作只产生一次成功事件。例如转写成功和笔记保存是同一成果，不算两次创作。一次 AI 改写可以成为新的成果，但重复点击保存、同步到另一台设备不新增成果。

后台完成的成果和用户实际看到的成果分别记录：`creation_completed` 与 `creation_result_viewed`。首次价值体验以“首个成果已保存且用户已看到”为准。

## 2. 新用户激活

### 分析问题

- 新用户是否完成登录、引导，并得到第一份成果？
- 第一次成功来自分享视频、录音、AI 还是其他入口？
- 登录后付费页面是否与首次创作流失相关？
- 分享扩展直接进入的用户，激活表现是否不同？

### 两条路径，避免强行串成一个漏斗

- 主应用路径：首次打开 → 引导/登录（按实际顺序）→ 首次登录付费页 → 付费或关闭 → 发起创作 → 成果保存 → 查看成果。
- 分享路径：外部视频分享到 ChillScript → 接收成功 → 必要时登录 → 文字生成并保存 → 查看成果。

付费不是激活的必经成功条件，关闭付费页后完成创作也应计入激活。

### 事件

| 事件 | 触发条件 |
| --- | --- |
| app_first_opened | 当前安装首次打开主应用；SDK 升级首次初始化不等同于新用户 |
| onboarding_started / onboarding_step_completed / onboarding_completed | 按稳定步骤 ID 记录引导开始、完成步骤、完成整个引导 |
| login_started / login_completed / login_failed | 用户主动登录的结果；静默恢复和 token 刷新不计新登录 |
| account_created | 后端确认真正创建新账号，仅一次；老账号在新设备登录不算注册 |
| creation_started / creation_completed / creation_failed | 发起核心创作、成果保存成功、明确失败 |
| creation_result_viewed | 前台界面已展示可用成果，每个成果首次展示时记录 |

### 指标口径

- 安装激活率：首次打开主应用后 24 小时内完成并查看成果的安装数 / 首次打开主应用的安装数。跨设备匿名阶段无法可靠合并，此指标明确按安装统计。
- 新账号激活率：账号创建后 24 小时内完成并查看成果的新账号数 / 新账号数。
- 首次价值耗时：首次打开/账号创建到首份成果被查看的耗时，分别报告中位数、90 分位数。
- 首次创作类型分布、引导各步骤流失率、首创作失败原因。
- 首创作时间由持久化的账号级事实确定。接入前老用户标记为 existing 或 unknown；不能把“第一次被 PostHog 观察到”称为“生涯第一次创作”。

## 3. TikTok、Instagram、YouTube 分享视频转文字

### 主流程

选择 ChillScript 分享入口 → 扩展/分享接收页打开 → 链接被可靠接收 → 发起转写 → 后端产出文字 → 成果保存 → 用户查看。

现有 iOS 扩展会保存待处理项目，并尝试启动远程任务；因此扩展显示完成不代表转写完成。Android 也有独立的分享接收 Activity。

### 事件与指标

| 事件 | 含义 |
| --- | --- |
| share_import_opened | ChillScript 扩展或安卓分享接收页确实打开 |
| share_import_accepted | 有效链接已进入持久队列；仅代表接收成功 |
| share_import_blocked | 未登录、额度不足、不支持链接等明确阻碍 |
| video_transcription_started | 一个实际转写尝试已开始 |
| video_transcription_completed / video_transcription_failed | 后端或唯一权威执行方确认非空文字产出/失败 |
| creation_completed | 转写成果保存完成，仅一次 |
| creation_result_viewed | 用户看到结果；没有打开主应用也要保留前面的真实完成事件 |

重点统计：

- 分享入口到接收成功率：接受的分享操作 / 打开的分享操作。
- 转写任务成功率：在 24 小时观察窗内成功的任务 / 已开始的任务；进行中、取消、失败分别显示。
- 端到端成功率：24 小时内成果保存成功的分享操作 / 已接收的分享操作。
- 成果查看率：保存后 24 小时内被查看的成果 / 已保存的成果。
- 耗时拆成排队、转写、保存、用户返回查看四段，报告中位数与 90 分位数。
- 按 TikTok / Instagram / YouTube、iOS / Android、版本分别比较；展示每组样本数。

属性：`source_platform`、`entry_point`、`surface`、`operation_id`、`attempt_id`、`duration_bucket`、`latency_ms`、`failure_stage`、`error_code`。

平台根据分享内容中的链接域名识别，不把它当作已知的“来源 App”。短链接无法可靠识别时记为 `unknown`，不上传原始链接、作者账号、视频标题或视频 ID。

观测限制：只能知道 ChillScript 分享入口实际被打开；无法知道用户在 TikTok/Instagram/YouTube 中打开分享菜单后没有选择 ChillScript 的次数。

## 4. 录音转写

### 流程

尝试录音 → 权限允许且实际开始录音 → 停止录音 → 发起转写 → 文字产出 → 成果保存 → 查看/继续处理。

事件：`recording_requested`、`recording_started`、`recording_stopped`、`recording_cancelled`、`recording_blocked`、`audio_transcription_started`、`audio_transcription_completed`、`audio_transcription_failed`，以及通用成果事件。

指标：录音启动成功率、主动取消率、录音到成果成功率、转写成功率、等待耗时、失败后重试成功率、转写后 AI Skill 使用率。

区分首次尝试与重试；一个 operation_id 可有多个 attempt_id。业务成功率按操作去重，技术成功率按尝试统计。用户主动取消不当成技术失败；没有结束事件的记录暂列“结果未知”。

属性只记录时长分桶、入口、结果、错误类别、耗时等，不记录音频或转写正文。语言仅用可靠的配置/识别结果，未知则不推测。

## 5. 首次成功创作 → 之后再次成功创作

建议同时看两种复用：

1. 再次完成任一类型创作，判断用户是否持续获得整体价值。
2. 再次完成首次使用的同类功能，判断分享转写、录音、AI、提词拍摄各自的复用。

以首次成功创作的日期为 Day 0；统一使用项目统计时区（目前为 UTC），只比较观察期已经完整结束的用户：

| 指标 | 定义 |
| --- | --- |
| 7 天再次创作率 | Day 1–7 至少再次完成一次创作的用户 / 有完整 7 天观察窗的首次创作用户 |
| 第二周创作留存 | Day 8–14 至少完成一次创作的用户 / 有完整 14 天观察窗的首次创作用户 |
| 第四周创作留存 | Day 22–28 至少完成一次创作的用户 / 有完整 28 天观察窗的首次创作用户 |
| 每周创作活跃用户 | 一周内至少完成一次创作的独立用户 |
| 每周创作天数 | 每位用户一周内发生成功创作的不同日期数 |

同一天连续完成多次不算“之后回来”；另做同日深度使用指标。同一成果由两端同步或多次打开不能重复计为创作。

按首次成功类型、首次内容来源平台、激活耗时、平台、事件发生时的订阅状态分组。关联关系只用于发现假设，不能直接认定某功能导致付费或留存提升。

## 6. 两个付费入口

统一事件，固定用 `paywall_placement` 区分：

- `post_login`：首次登录后的付费引导。
- `settings`：从设置进入的付费页。

不要用“所有 standard 页面都是 settings”来推断来源，入口必须显式传递。将来有新入口单独增加枚举。

当前首次登录后的订阅体验包含介绍与价格页，分开记录：

| 事件 | 触发条件 |
| --- | --- |
| paywall_intro_viewed | 介绍页实际可见 |
| paywall_viewed | 价格和购买按钮已加载且实际可见；一次展示周期一次 |
| paywall_plan_selected | 用户选择套餐 |
| purchase_started | 实际发起商店购买流程 |
| purchase_cancelled / purchase_failed | 主动取消或明确失败，分开统计 |
| subscription_started | 权威确认新增订阅权益，可为 trial 或 paid |
| payment_succeeded | 实际成功收费；试用开始不能当成收入 |
| purchase_restored | 恢复既有购买，不算新增订阅或收入 |
| paywall_dismissed | 页面关闭且未完成购买；崩溃或被系统杀死不能推断为主动关闭 |

关键属性：`paywall_placement`、`paywall_view_id`、`purchase_attempt_id`、`plan_id`、`offer_type`、`trial_eligible`、`currency`、`price_minor_units`、`subscription_state`。界面展示价格和实际支付金额分开。

看板分别报告：

- 价格页到购买发起率、发起到新增订阅成功率。
- 24 小时价格页到新增订阅转化率，分试用和直接付费。
- 试用结束后的首次付费率：必须等待完整试用及必要支付结算窗口。
- 关闭首次登录付费页后，24 小时内的首次创作率。
- 设置付费页转化时，用户此前完成的创作次数/类型。

主要入口归因取购买发起时关联的 paywall_view_id；后端确认事件沿用该来源。无法关联标记 unknown，不硬归到最近一次打开的页面。自动续费、退款不能归为一次新的付费页转化。

RevenueCat/商店服务端确认作为订阅、实际支付与恢复的权威依据。客户端“已购买”提示仅用于界面诊断。RevenueCat 官方 PostHog 集成使用 `rc_*` 服务端事件计算试用转付费、续费、取消、到期和账单问题；客户端事件继续负责记录价格页入口与购买意图。

两个入口用户意图不同，不能仅比较转化率就认定某个页面更好；至少按账号年龄、历史创作、试用资格分组，并显示样本量。

## 7. AI Skill

流程：打开 Skill 列表 → 选择 Skill → 发起生成 → 生成成功 → 采用/另存/复制/导出。

事件：`skill_picker_viewed`、`skill_selected`、`skill_run_started`、`skill_run_completed`、`skill_run_failed`、`skill_result_used`。

属性：`skill_key`、`skill_origin`（内置/自定义）、`input_type`（视频转写/录音转写/文本）、`action`（采用/另存/复制/导出）、`latency_ms`、`error_code`。

自定义 Skill 名称、提示词和内容不得上报。skill_key 用稳定内部分析标识；无可靠标识时聚合为 custom。

核心指标：每个 Skill 的独立使用人数、生成成功率、结果使用率、首次成功后 7 天再次使用率、由视频/录音转写进入 Skill 的比例。

“结果使用率”按同一 run_id 在 24 小时内至少一次使用 / 成功生成的 run_id。一次结果被采用又复制仍只算一次被使用。采用、另存或导出成功可产生一次 creation_completed；只复制作为使用信号，不单独算成功创作。

## 8. 提词器

流程：打开提词器 → 开始滚动阅读 → 发起拍摄 → 视频保存/导出。

事件：`teleprompter_opened`、`teleprompter_playback_started`、`teleprompter_recording_started`、`teleprompter_recording_stopped`、`teleprompter_recording_cancelled`、`teleprompter_video_saved`、`teleprompter_failed`。

指标：打开到开始阅读比例、打开到开始拍摄比例、拍摄到视频保存成功率、取消/失败原因、7 天再次使用率。阅读型和拍摄型使用分开，单纯阅读不能被当成拍摄流失。

属性：`script_source_type`（AI结果/视频转写/录音转写/文本）、`duration_bucket`、`camera_position`、`error_code`。不传稿件、视频或精确文件路径。

视频保存或导出第一次成功时产生一次 creation_completed；反复导出同一视频不重复计数。滚动阅读开始是使用信号，不能推断用户已读完全文。

## 9. 双端与异步链路的数据规则

- 公共属性：`platform`、`environment`、`app_version`（尽量复用 SDK 版本属性）、`surface`、`entry_point`、`schema_version`、事件时的 subscription_state。
- `surface` 固定区分主应用、iOS 分享扩展、Android 分享接收页、server；业务事件共用词典，不把两端事件拆成不同名字。
- 登录前保留匿名身份，登录后关联小写账号 UUID。退出/换号必须重置；身份保存在操作创建时的上下文中，延迟结果不能记到后来登录的另一个账号。
- 每次业务操作用独立 operation_id，每次尝试用 attempt_id。事件唯一标识在首次产生时固定并持久化；发送重试复用同一个标识。单纯加入 operation_id 属性不会自动获得去重能力。
- 明确每个事件的唯一权威发出点。服务端负责转写任务最终结果、订阅支付结果；客户端负责用户动作、实际保存/展示。不同阶段不复用同一个完成事件。
- iOS 分享扩展使用已有共享容器和兼容标识，设计轻量持久事件队列；不能依赖扩展关闭前一次 flush 必然送达。主应用/后端补发保留原发生时间和原身份。
- 没有返回主应用时也需能确认后端任务结果；只有客户端可观察的扩展打开/结果查看，明确承认可能因扩展被杀或卸载而漏报。不能拿“下次启动时补发”冒充无损实时采集。
- 后端任务产出与客户端保存可达成不同状态，单独保留“后端完成、待客户端保存”，不把服务端成功直接当成用户已拿到成果。
- 不依赖安装事件判定新账号；接入前历史、后台导入、示例内容和同步单独排除。
- 不把应用进入后台直接算放弃。漏斗未转化必须等观察窗结束，保留 pending/unknown 分类。
- 每条看板默认 production，排除测试账号，保留版本分组和分母。首轮采集稳定后建立基线，再定目标，不编造行业基准。
- 延续不采集正文、录音、URL、用户名、邮箱、提示词、原始错误的规则；仅上报固定错误码。正式发布前同步披露新增用途，并补齐分析数据删除和用户选择机制的实现设计。

## 10. 建议建立的看板

1. **总览**：新账号、24 小时激活率、周创作用户、7 天再次创作率、双入口新增订阅。
2. **新用户激活**：主应用与分享路径分开，首个价值来源、耗时、引导/付费页后的流失。
3. **分享视频转文字**：三平台的接收、转写、保存、查看、耗时及失败类别。
4. **录音转写**：权限阻碍、取消、转写成功、重试恢复、完成耗时。
5. **创作留存**：首次来源类型、次周/第四周复用、每周创作天数。
6. **付费转化**：首次登录与设置两个独立漏斗，区分试用/收费/恢复。
7. **AI 与提词器**：Skill 成果使用、提词阅读、拍摄成果、重复使用。

## 11. 实施顺序与验收

第一阶段：统一事件词典、身份/去重/异步上下文；接入激活、分享转文字、录音转写、通用创作事件；双付费入口展示与购买尝试也在这一阶段采集，尽早积累入口数据。

第二阶段：接入 RevenueCat 服务端订阅/支付确认与入口关联；补齐 AI Skill、提词器及相关成果事件。

第三阶段：建立生产看板，积累完整观察窗；先观察 1–2 周形成激活/成功率基线，第四周留存至少等待 28 天完整数据。样本少时同时报告人数和比例。

验收覆盖：iOS/Android 正常流程、短链未知平台、未登录、权限拒绝、额度不足、网络断开、超时、重试、强制退出、延迟完成、跨设备同步、账号切换、试用/直接购买/恢复/取消、支付回调重试。

通过标准：每个真实操作的开始和结果可关联；完成事件不重复；成功一定有可用成果；两个付费入口不串；延期上报保留原时间及身份；禁止字段不出现在 payload；开发数据不进入正式看板。

本方案不启用录屏，不调整付费页产品行为，不发布版本或改变现有兼容标识。若实施涉及共享协议或服务端字段，届时按仓库规则检查双端兼容。

## 参考

- [当前基础接入及验证](POSTHOG.md)
- [PostHog 留存：区分起始和回访事件](https://posthog.com/docs/new-to-posthog/retention)
- [PostHog 事件及去重](https://posthog.com/docs/data/events#event-deduplication)
- [PostHog iOS 身份关联](https://posthog.com/docs/libraries/ios/usage#identifying-users)

代码核对依据：`ios/ChillNoteShareExtension/ShareImportService.swift`、`ios/chillnote/Features/Home/HomeView+SharedImports.swift`、`ios/chillnote/Features/SubscriptionView.swift`、`android/app/src/main/java/com/sponteoai/chillscript/share/ShareImportActivity.kt`。
