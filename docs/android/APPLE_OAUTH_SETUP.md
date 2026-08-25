# Android Apple 登录安全配置

客户端已经使用授权码 + S256 PKCE，不再从回调 URL 接收 `access_token` 或
`refresh_token`。默认仍使用 `chillscript://auth-callback`，这样本地开发不会依赖网站配置。

公开上架前建议切换到已经验证归属的 HTTPS App Link：

1. 在 Play Console 取得 **App signing key certificate** 的 SHA-256 指纹，不要使用本地
   Debug 证书代替正式指纹。
2. 在 `https://www.chillnoteai.com/.well-known/assetlinks.json` 部署 Android 官方格式的
   Digital Asset Links 文件，包名为 `com.sponteoai.chillscript`，指纹使用上一步的值。
3. 在 Supabase Auth 的 Redirect URLs 中加入
   `https://www.chillnoteai.com/auth/android/callback`；本地测试若继续使用自定义 scheme，
   也需允许带一次性 `oauth_request_id` 查询参数的 callback。
4. 通过环境变量或 `android/local.properties` 切换客户端：

```text
CHILLSCRIPT_ANDROID_AUTH_REDIRECT_URI=https://www.chillnoteai.com/auth/android/callback
```

本地属性名为：

```text
chillscript.auth.redirectUri=https://www.chillnoteai.com/auth/android/callback
```

5. 用 Internal testing 安装由 Google Play 签名的候选包，验证 Apple 登录、取消、重复回调、
   浏览器返回、应用被系统回收后继续登录，以及其他 App 不能接管该 HTTPS 回调。

在 `assetlinks.json`、Supabase allowlist 和 Play 签名指纹三项完成前，不要把生产
`AUTH_REDIRECT_URI` 切到 HTTPS。
