# Server Instructions

- `server/` 是 iOS 与 Android 共用的生产后端，不是登录后 Web App 的附属目录。
- 删除或修改接口前，先搜索两个移动客户端的调用方，并考虑旧版本客户端兼容。
- Prisma schema 变更必须使用新的迁移；不要改写已经执行过的迁移。
- 不要提交密钥、服务账号、数据库文件或生产环境变量。
- 订阅逻辑需区分 Apple、Google Play 和历史网页支付，不要用一个平台的状态覆盖另一个平台。

## Verification

以下命令从 `server/` 运行：

- TypeScript 或构建配置变更：`npm run build`。
- 行为变更：`npm test`；范围明确时可用 `npx --no-install tsx --test src/相关文件.test.ts` 运行对应测试。
- 接口与同步协议变更：补充成功、失败及旧客户端兼容用例，并检查两个移动端调用方；本地构建不代表生产迁移或部署已完成。
