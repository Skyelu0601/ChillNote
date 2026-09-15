# 2026-09-12 异常原因调查

本次沿用巡检固定窗口：2026-09-11 11:45:58 UTC 至 2026-09-12 11:45:58 UTC（北京时间每天 19:45:58 对齐）。检查代码、已取得的 PostHog 汇总与崩溃栈，并只读核对生产服务器 Nginx/应用日志。没有修改业务代码、线上配置或发布版本。

**更正上一份报告的表述：21 条 `generation_failed` 不能称为 21 次已确认的 AI 技术故障。** 代码证明这个类别还包括拒绝 AI 授权等情况。额度不足虽已另列，其他正常退出仍未排除。

## 1. 编辑器崩溃：已定位触发路径，具体运行时根因仍待复现

[真实崩溃](https://us.posthog.com/project/596105/error_tracking/01a0931c-98ba-7600-b634-ebf357a78d2f)：iOS 1.2.15，iOS 18.7.10，9 月 12 日北京时间 08:54，1 次/1 人。

已解析调用链：
- RichTextEditorView.dismantleUIView，RichTextEditorView.swift:160。
- Coordinator.flushPendingChanges，:269。
- Coordinator.publishSelection，:319。
- NoteDetailViewModel.editorSelection setter → Combine → SwiftUI → Swift runtime → abort。

本地源码与栈一致：销毁编辑器时仍调用 flush，而 flush 不仅保存文字，还通过 Binding 回写选区；选区是 @Published，赋值会通知 SwiftUI 刷新界面。**高度怀疑视图正在销毁时又触发界面状态通知的生命周期冲突**。没有证据指向支付、AI 接口、输入内容本身或新装的 PostHog SDK 是崩溃根因。

但系统框架栈尚未解析到具体函数，异常文字已脱敏，不能进一步把它确定为某一种 Swift 断言、重复访问或悬空引用。苹果说明 dismantleUIView 属于移除视图前的清理阶段；该 API 本身不禁止所有界面更新，因此不能仅凭“这里写状态”就声称复现了崩溃。

当前 1.2.16 源码仍保留上述路径，升级版本号本身没有修复它。后续应在视图仍有效时完成必要文字提交，拆卸时取消延迟任务/回调并断开 delegate，避免在拆卸过程中继续发布选区等界面状态，同时验证文字保存不丢失。需重点复现编辑后立即返回、滑动返回、切换笔记和切换编辑页签。

本机只读确认有 iOS 18.6、26.2、26.5 模拟器，没有事发的 iOS 18.7.10；本次未做设备现场复现或模拟器交互测试。

代码：[编辑器销毁与提交](../../ios/chillnote/Core/Components/RichTextEditorView.swift)、[选区 @Published](../../ios/chillnote/Features/NoteDetail/NoteDetailViewModel.swift)、[页面退出提交](../../ios/chillnote/Features/NoteDetail/NoteDetailRootView.swift)。

参考：[Apple dismantleUIView 说明](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/dismantleuiview%28_%3Acoordinator%3A%29)。

## 2. AI 失败：已确认分类混入拒绝授权，未发现服务器整体故障证据

iOS 当前顺序是：
1. 记录 skill_run_started。
2. 进入 GeminiService.generateContent。
3. 检查 AI 数据授权；拒绝则抛 consentDeclined，根本不会发送 AI 请求。
4. 外层 catch 只单独区分 insufficientCredits，其余一律记录 generation_failed。

因此，**用户点击“不允许 AI 处理我的内容”，也会被当成生成失败记录，且走错误展示分支**。这是代码可确认的统计和交互分类问题；不是已经证明 21 次都由拒绝授权造成。

Android 的顺序不同：先等待 AI 授权，拒绝直接结束；授权通过后才记录 skill_run_started，所以 Android 不会把同类拒绝记入此失败类别。这个口径差异可能解释部分跨平台差异，不能用于直接分配历史 21 次的原因。

同一个 iOS generation_failed 还可能包括：
- 获取不到登录令牌，请求尚未发出；
- 网络中断、客户端超时/取消；
- HTTP 429 或其他服务器错误；
- 返回格式无法解析。

本次只读汇总生产 Nginx access.log 与当天轮转日志，日志时区 -07:00 已转换为 UTC 对齐同一窗口。/ai/gemini 共观察到：
- HTTP 200：502 次，其中识别为 iOS 的 151 次。
- HTTP 402（额度不足）：46 次，其中 iOS 10 次。
- 没有观察到该接口 HTTP 429、499、5xx 等状态。

iOS 依据 User-Agent 中 CFNetwork/Darwin 判断；其余 387 次未强行归类为 Android。日志覆盖了所选完整窗口。该接口还服务其他 AI 功能，故这些请求不能直接与 152 次 skill_run_started 配对。

这组证据**不支持本次是 Gemini 整体宕机、接口限流或服务器普遍超时**。但 HTTP 200 不等于客户端最终展示成功，未到服务器的断网/授权拒绝也不在 Nginx 日志里；不能据此排除所有技术问题或宣称全部 21 次均为正常取消。

PM2 旧错误日志未系统记录时间，不能把其中历史 Gemini 错误归到这个 24 小时窗口。未输出原始错误正文、提示词、IP 或用户身份。

建议后续将 consent_declined、auth_required、network、timeout、http_error、invalid_response 分开记录，并添加安全的阶段、状态码和耗时，继续不上传用户内容。当前历史事件没有具体错误字段，无法准确恢复每次的原因。

代码：[iOS AI 入口](../../ios/chillnote/Features/NoteDetail/NoteDetailViewModel+AI.swift)、[授权与请求](../../ios/chillnote/Services/GeminiService.swift)、[授权管理器](../../ios/chillnote/Services/AIConsentManager.swift)、[Android 对照](../../android/app/src/main/java/com/sponteoai/chillscript/AppViewModel.kt)、[服务端接口](../../server/src/index.ts)。

## 3. 登录错误：Google 取消与实际失败混在一起，Apple 两次仍需诊断

巡检窗口 iOS 19 次/16 人：Google 17 次/14 人、Apple 2 次/2 人。Google 同期仍有 91 条完成事件（91 人），不能认定所有用户都无法登录。

Google SDK 明确将主动取消作为 canceled/-5 返回；AuthService.signInWithGoogle 把整个 SDK 登录和后续令牌交换包在同一个 catch，统一记录 provider_error，并显示原始错误信息。因此用户关闭授权窗口，也可能既增加失败计数又看见错误提示。

无法从这 17 条历史 provider_error 里分辨用户取消、Google SDK 问题、网络故障或登录令牌交换问题。需要记录 SDK 错误域/固定错误码和阶段，并将取消单独处理。

Apple 的这 2 条 provider_error 来自拿到 Apple credential 后的登录令牌交换/会话处理 catch；不能套用 Google 的取消解释。现有字段不足以进一步确认原因。登录由 Supabase 处理，AI 服务器的 Nginx 日志不包含完整的 Google/Apple 登录链路，本次没有以 AI 日志代替认证服务日志下结论。

代码：[AuthService.swift](../../ios/chillnote/Services/AuthService.swift)。参考：[Google 官方 canceled 错误定义](https://developers.google.com/identity/sign-in/ios/reference/Enums/GIDSignInErrorCode)。

## 验证与剩余边界

- 已完成：真实脱敏崩溃栈与源代码对照；iOS/Android 授权与错误分类比较；生产 AI 接口状态码按同一窗口汇总；模拟器系统版本只读盘点。
- 未执行：业务修改、构建、单元测试、设备复现、付费试购、修改权限或部署。
- 更细的 PostHog 操作配对查询未完成：连接工具在调查中发生网络中断；本机 CLI 只有之前授权的错误追踪/组织权限，不具备 query:read，未擅自扩大权限。浏览器当前也没有登录。已有巡检汇总与崩溃记录保留；历史错误原因字段本身未采集，连接恢复也不能还原未记录的信息。
- 处理优先级：编辑器关闭崩溃；AI 拒绝授权和 Google 取消登录的分类/提示；补充具体诊断，再针对剩余真实失败修复。

