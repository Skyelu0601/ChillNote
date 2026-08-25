# Server Instructions

- `server/` 是 iOS 与 Android 共用的生产后端，不是登录后 Web App 的附属目录。
- 删除或修改接口前，先搜索两个移动客户端的调用方，并考虑旧版本客户端兼容。
- Prisma schema 变更必须使用新的迁移；不要改写已经执行过的迁移。
- 不要提交密钥、服务账号、数据库文件或生产环境变量。
- 订阅逻辑需区分 Apple、Google Play 和历史网页支付，不要用一个平台的状态覆盖另一个平台。

## Verification

```bash
cd server
npm test
npm run build
```
