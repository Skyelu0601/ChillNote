# Android / iOS 功能一致性清单

这份清单以当前 iOS 源码为事实来源，而不是以旧需求文档或猜测为准。

实际执行顺序请同时参考 `docs/android/GOOGLE_PLAY_LAUNCH_RUNBOOK.md`。

- `[x]`：Android 当前可达实现已经按 iOS 源码接入，并通过本轮可运行的静态检查。
- `[ ]`：仍缺实现、外部配置或真机验证，不能作为已经完成对外承诺。
- “图片附件”和“邀请”已从旧清单删除：当前 iOS 没有照片选择/图片附件入口，也没有邀请功能。iOS 富文本代码中的 `NSTextAttachment` 只用于清单勾选框显示。

## 已实现的功能

### 启动、账户与订阅

- [x] 首次启动引导页、欢迎笔记和首次登录订阅页
- [x] Google、Apple PKCE、邮箱验证码登录代码
- [x] 会话恢复、退出确认、删除账户和本地数据清理
- [x] AI 数据处理同意流程
- [x] Google Play Billing、试用资格展示、恢复购买、订阅管理和额度

### 笔记、标签与同步

- [x] Inbox、Drafts、Published、Trash 工作流
- [x] Markdown 编辑/预览、粗体、H1/H2、清单、撤销/重做
- [x] 置顶、全文搜索、批量选择、移动、加标签和删除
- [x] 回收站恢复、彻底删除、到期自动清理和硬删除队列
- [x] 标签创建、编辑、删除、颜色、多级父子关系、排序、移动和筛选
- [x] Room 离线数据、FTS 搜索、迁移和 `/sync` 双向同步/冲突处理

### 采集与 AI

- [x] Android 系统分享、链接导入、后台任务轮询和来源卡片
- [x] 前台剪贴板创作者链接识别、去重和导入额度扣减
- [x] 语音录制、立即打开空笔记、编辑器内转写/润色阶段、显示原文和待处理录音恢复
- [x] Creator Skills、自定义技能、翻译、预览、应用、重试、撤销和保存
- [x] 多笔记 AI Context Chat
- [x] 初始礼物额度提示
- [x] 首次成功语音/链接导入后直接调用 Google Play 原生评分流程（无评分预筛选）

### 提词器、系统入口与导出

- [x] 提词器脚本、字号、速度、滚动、按相机真实能力展示清晰度、分段录制、重录、合成和导出
- [x] 主屏幕 Brain Dump 小组件及 `chillscript://record` / `chillnote://record` 深链接
- [x] Android 快捷设置 Brain Dump 按钮（对应 iOS Control Center 控件）
- [x] 单篇 Markdown、文本、JSON 导出
- [x] 全部笔记 ZIP 导出、真实进度、取消和半成品清理
- [x] 语言、语音偏好、保存链接区块、关于、隐私、条款和权限入口

## 当前验证证据

- [x] 8 种语言共 724 个字符串和 6 个复数资源；7 个非英语目录无缺键、占位符错误或未允许的英语回退
- [x] 25 个本地化/生成器测试通过；7 个非英语生成目标均为零差异
- [x] 当前 Android 资源引用无缺失，主资源 XML 与 `git diff --check` 通过
- [x] `compileSdk` / `targetSdk` 为 36，`versionName` 为 1.2.6；release 缺签名时会主动失败
- [x] 512×512 图标与 1024×500 Feature Graphic 的硬规格合格
- [x] 旧 Material 商店截图已隔离，正式截图目录保持为空，避免误上传旧界面
- [ ] 最新合并候选版尚未重新运行 Gradle、设备测试或同尺寸/同状态 iOS–Android 视觉对照；之前的通过记录不能替代本次候选版验证

## 上架前仍需完成

- [ ] 在 Android 真机验证 Google/Apple/邮箱登录、Play Billing 购买/恢复、麦克风、相机、视频合成、系统分享、小组件和快捷设置按钮
- [ ] 用最终候选提交重新运行 `testDebugUnitTest`、`lintDebug`、`assembleDebug`，并完成 API 26、主流版本和 API 36 回归
- [ ] 使用相同语言、数据、设备画布和交互状态重新拍摄 iOS/Android 对照；现有历史对比图不能证明最终像素一致
- [ ] 从最终 Android 候选包拍摄至少 2 张正式 Play 截图；当前正式目录为 0 张
- [ ] 在 Play Console Internal testing 轨道验证真实商品、试用资格、购买回调和应用内评分
- [ ] 在部署后的真实后端补 `/sync` 登录态联调（本地 Room + 模拟服务器响应的同步集成测试已覆盖）
- [ ] 覆盖 Android 8、当前主流版本和最新版本的关键路径
- [ ] 在真机完成 TalkBack 手动走查（自动无障碍检查、低存储、深色模式、横竖屏和 130% 大字号已在模拟器通过）
- [ ] 生成正式上传密钥并验证已签名 AAB；当前 AAB 仍是未签名构建产物
- [ ] 用 Play App Signing SHA-256 部署 `assetlinks.json`，在 Supabase 加入 HTTPS callback，再把 Apple OAuth 从 PKCE 自定义 scheme 切到 Verified App Link
- [ ] 配置 Google Play RTDN/Pub/Sub、消息去重与退款/撤销/暂停权益对账后再公开收费
- [ ] 配置生产 Firebase/FCM、Google Android OAuth SHA 指纹和可重复使用的审核登录方式，并在 Internal testing 真机验证
- [ ] 部署并在线验证账户删除网页
- [ ] 在 Play Console 完成数据安全、内容分级、目标受众、隐私政策、商店文案和素材

## 已知测试环境问题

- 本轮最终合并后，Codex 沙箱无法访问本机 Gradle 缓存；额外权限请求又受当前使用额度限制。因此最新候选版没有重新编译。这是验证环境限制，不代表项目已经通过或已经失败。
- 之前用于截图的 API 36 模拟器出现 System UI / Digital Wellbeing ANR，无法产出可信的最终同状态截图；必须用稳定模拟器或真机重拍。
