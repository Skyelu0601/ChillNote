# ChillScript 免费工具

## 页面与搜索意图

6 个路径：`/tiktok-transcript`、`/youtube-transcript`、`/video-to-script`、`/tiktok-to-script`、`/video-to-notes`、`/instagram-reel-transcript`。

所有网页体验统一为：粘贴视频 URL → 查看/复制 Transcript → 下载 ChillScript。脚本、Hook、灵感和笔记相关页面明确说明后续创作发生在 App 内；网页不提供这些 AI 操作或对应生成接口，不承诺免费的网页脚本/Hook 生成。

`/tools` 为入口合集。各页使用静态渲染、独立 title/description/canonical、Open Graph、WebApplication/BreadcrumbList 结构化数据、可见 FAQ 和相互链接。sitemap 从同一个工具目录生成，不维护重复的静态 XML。页面英文与现有官网一致，词条集中在 `src/lib/free-tools-copy.ts`。

这是首批搜索意图覆盖，不代表已验证搜索量、排名或付费转化率。页面采用真实视频链接流程，不提供伪造结果或演示结果冒充真实输出。

## 服务连接与上线

下载区域使用浅色自定义按钮，搭配 Apple 标识和彩色 Google Play 符号；下载链接及工具来源参数不变。

1. 在现有单进程后端部署 `server/`。新增 `/free-tools/jobs`，旧移动端 `/ai/*` 和登录/额度/同步接口保持原有行为。
2. 官网和后端设置相同的 **`FREE_TOOLS_SECRET`**（至少 32 个字符的随机秘密），仅服务器可见，不加 `NEXT_PUBLIC_` 前缀、不提交到仓库。
3. 官网设置 **`FREE_TOOLS_BACKEND_URL`** 为现有后端 HTTPS origin，不能指向官网或带 `/free-tools` 路径。
4. 后端沿用已有 `GEMINI_API_KEY`、`GEMINI_MODEL` 和媒体解析配置，以及 `yt-dlp` / `ffmpeg` 运行环境。免费入口本身不安装这些依赖。
5. 在 Vercel 部署官网。匿名配额身份来自 Vercel 覆写的 `x-vercel-forwarded-for`，经 HMAC 后传给后端，不信任来访者自行提供的 `x-forwarded-for`。其他生产托管平台默认拒绝服务，须先适配可信入口。
6. 部署后用三平台真实公开链接验证成功、受限视频、超时、并发、额度和转录结果，再在 Search Console 提交 `/sitemap.xml`。

缺少配置时，页面仍可预览，但提交返回明确的“暂时不可用”，不会产生虚假 transcript。开发环境统一使用 `local-preview` 配额身份。生产构建本地测试可设置 `FREE_TOOLS_ALLOW_LOCAL=true`；**不要在公开非 Vercel 部署使用这个测试开关**。

前端只把请求发给同域 `/api/free-tools/jobs`，由 Next.js 转发。转录运行在现有后端的后台任务中，官网轮询结果，不依赖 Vercel 长连接等待整个转录。

## 首版容量和数据

- 每个网络/IP 每个 UTC 日最多 3 次视频请求；共享网络共享额度；失败请求也计数。
- 全站默认每日 100 次视频请求，可用后端 `FREE_TOOLS_DAILY_LIMIT` 调整。
- 最多 2 个并发转录任务；最多 300 个保留会话。
- 成功或失败的转录会话保留约 30 分钟，空闲结果每分钟清理；处理中的任务受现有媒体处理超时约束，完成后进入保留期。
- 结果及限额保存在单个后端进程内存中，重启会丢失、额度会重置。符合当前 PM2 `instances: 1`；扩容到多实例前必须迁移到共享队列/存储及持久化配额，不能把当前每日额度视为持久账单上限。
- 免费入口只接受指定平台的视频 URL，不把原始异常或 API 密钥返回浏览器。
- 用户可复制完整 Transcript；页面提示核对原视频中的人名和引文。
- 网页不创建 App 账号或笔记，也不自动同步结果。下载后引导用户分享原视频，在 App 完成首次导入。

## 转化测量

页面向 `window.dataLayer` 发出以下事件，包含 `tool_slug`，不含视频 URL、transcript：

- `free_tool_viewed`
- `free_tool_transcript_started` / `free_tool_transcript_completed`
- `free_tool_result_copied`
- `free_tool_download_clicked`（`platform`）
- `free_tool_failed`（白名单 `reason`）

**目前这是埋点接口，不是已接通的数据报表。** 官网尚未配置消费 dataLayer 的分析服务。上线时按隐私/同意设置接入分析平台，再验证事件入库。App 已有激活/付费事件与新网页事件是不同部分。

Google Play 下载 URL 包含按工具区分的 Install Referrer 参数。iOS 包含工具 campaign token (`ct`)，完整 App Store 活动归因还需 App Store Connect 的 provider token (`pt`) 等配置。不能仅凭这两个链接参数宣称网页访客已与 App 用户关联。

分阶段观察：Search Console 页面曝光/点击 → transcript 成功率 → 商店点击率 → App 首次成功视频导入 → 首次脚本生成 → 付费。跨安装身份串联需配合 Android Install Referrer、iOS 支持的活动测量和 App 事件单独实现；本次不修改已发布 App 标识和登录流程。

## 验证

官网：`npm run typecheck`、`npm run build`，浏览器检查桌面/手机页面、真实表单状态及链接。

后端：`npm run build`；`npx --no-install tsx --test src/freeTools.test.ts src/tiktokTranscript.test.ts src/linkImportPolicy.test.ts`。新测试使用注入的转录服务，覆盖 URL 验证、鉴权、结果隔离、无网页生成接口、错误脱敏、额度、并发和过期，不代替外部平台的真实转录验收。
