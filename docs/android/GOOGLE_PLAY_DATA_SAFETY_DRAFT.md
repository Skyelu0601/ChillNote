# Google Play 数据安全表草稿

> 这是根据当前 Android 客户端、后端接口和 iOS 隐私清单整理的填写底稿，不是法律意见。提交前仍需确认生产环境日志、Supabase、Google Gemini 和其他服务商的实际保留策略。

## 表单总览

- 是否收集或共享用户数据：**是**
- 所有传输是否加密：**是**，客户端接口使用 HTTPS
- 是否提供账号删除：**是**
  - App 内：`Settings` → `Delete account`
  - 网页：`https://www.chillnoteai.com/delete-account`
- 隐私政策：`https://www.chillnoteai.com/privacy`
- 是否包含广告：**否**
- 是否用于跨应用或跨网站追踪：**否**
- 是否出售用户数据：**否**

Google 将“离开设备传输”视为收集。语音即使只为一次请求临时处理，也应在表单中申报，并在对应问题中选择临时处理。只在设备上生成、保存和导出的提词器视频不属于收集。

## 建议申报的数据类型

| Play 数据类型 | 收集 | 共享 | 必需/可选 | 用途 | 当前实现依据 |
|---|---:|---:|---|---|---|
| 个人信息 → 电子邮件地址 | 是 | 否* | 必需 | App 功能、账号管理 | 邮箱验证码、Google/Apple 登录、Supabase Auth |
| 个人信息 → 姓名 | 可能 | 否* | 可选 | App 功能、账号管理 | Google/Apple 登录可能返回显示名称；提交前确认生产端是否保存 |
| 个人信息 → 用户 ID | 是 | 否* | 必需 | App 功能、账号管理 | Supabase 用户 ID 与同步数据关联 |
| 财务信息 → 购买记录 | 是 | 否* | 可选 | App 功能、账号管理 | Google Play Billing 的商品 ID、购买令牌、订阅状态和到期时间 |
| 用户内容 → 其他用户生成的内容 | 是 | 否* | 可选 | App 功能 | 笔记、标签、AI 指令、导入链接产生的文本同步到服务器 |
| 音频文件 → 语音或声音录音 | 是，临时处理 | 否* | 可选 | App 功能 | 用户主动录音后发送至 ChillScript 服务器和 Gemini 转写；服务器不保留原始音频 |
| 设备或其他 ID | 是 | 否* | 必需 | App 功能、安全与防欺诈 | App 生成的同步设备 ID；提交前确认服务器日志是否还保存其他标识符 |

`否*` 的前提是 Supabase、Google Cloud/Gemini 等以 ChillScript 的服务提供商身份代表开发者处理数据，且不会将数据用于自身独立目的。Google 对“共享”的定义排除第一方服务提供商，但最终答案必须与合同和生产配置一致。

## 当前不建议申报为收集

- 照片和视频：提词器相机视频仅保存在 App 私有目录，用户主动保存到相册或分享；当前没有上传接口。
- 崩溃日志、性能和分析：Android 客户端未集成 Firebase Analytics、Crashlytics 或广告 SDK。若发布前新增，必须重新更新表单。
- 位置信息、联系人、短信、通话记录、健康信息：Manifest 没有对应权限，也没有相关功能。
- 麦克风和相机权限本身不等于数据收集；是否申报取决于数据是否离开设备。相机视频不上传，语音录音会上传处理。

## 删除与保留

- App 内删除会调用 `DELETE /auth/account`，删除业务数据库用户数据与 Supabase Auth 用户。
- Android 随后清理该用户在 Room 中的笔记、标签、清单关系、同步状态、待删除队列、待处理录音、自定义 Creator Skills 和相关本地状态。
- 网页提供无需重新安装 App 的邮件删除入口。
- 删除账号不会自动取消 Google Play 或 App Store 管理的订阅；删除网页已明确提示用户单独取消续订。
- 隐私政策目前声明：原始音频仅临时处理；待处理本地录音成功后删除或最长保留 7 天；文本笔记保留到用户删除内容或账号。

## 提交前必须人工确认

- [ ] 生产服务器、反向代理和日志平台是否保存 IP 地址、请求正文、设备信息或错误详情
- [ ] Supabase 的数据安全说明和数据处理协议是否与“服务提供商、不共享”答案一致
- [ ] Google Gemini/Google Cloud 的数据处理与保留设置是否与隐私政策一致
- [ ] Google Play Billing 验证数据库实际保存了哪些购买字段
- [ ] Play Console 开发者实体名称与隐私政策里的 `Sponteoai` 一致
- [ ] `https://www.chillnoteai.com/delete-account` 已部署并可从未登录浏览器正常访问
- [ ] 以后新增任何分析、崩溃、广告或推送 SDK 时重新审核本表

## Google 官方参考

- 数据安全表说明：<https://support.google.com/googleplay/android-developer/answer/10787469>
- 账号删除要求：<https://support.google.com/googleplay/android-developer/answer/13327111>
- 用户数据政策：<https://support.google.com/googleplay/android-developer/answer/10144311>
