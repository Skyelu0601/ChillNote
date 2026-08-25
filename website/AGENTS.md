# Website Instructions

- `website/` 是公开营销官网，不提供登录后的 Web App。
- 允许维护的页面包括首页、价格、隐私政策、服务条款和账号删除说明。
- 不要新增账号登录、笔记同步、网页编辑器、录音、AI Skills 或网页订阅购买流程。
- 下载入口应跳转到 App Store 或 Google Play，不应链接到 `/app`。
- 合规页面被 iOS、Google Play 和应用内链接使用，删除或改路径前必须检查移动端引用。
- 遵循 Next.js App Router 约定；只有需要浏览器 API 或交互状态的组件才使用 `"use client"`。

## Verification

```bash
cd website
npm run typecheck
npm run build
```
