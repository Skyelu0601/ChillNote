# Android Firebase 推送配置

Android 推送使用 Firebase Messaging BoM `34.17.0` 与当前 FID 注册接口
（`register` / `onRegistered` / `unregister`）。项目不依赖 `google-services.json`，
因此仓库和 CI 在没有生产凭据时仍能正常编译；运行时会安全关闭推送能力。

## 1. Firebase 项目

1. 在 Firebase 项目中注册 Android 应用 `com.sponteoai.chillscript`。
2. 启用 Firebase Cloud Messaging API 与 FCM Registration API。
3. 记录 Web API Key、Android App ID、Project ID 和 Project Number（Sender ID）。

不要把 Firebase 配置文件、服务账号 JSON 或私钥提交到 Git。

## 2. Android 构建配置

生产 CI 建议设置以下环境变量：

- `CHILLSCRIPT_FIREBASE_API_KEY`
- `CHILLSCRIPT_FIREBASE_APP_ID`
- `CHILLSCRIPT_FIREBASE_PROJECT_ID`
- `CHILLSCRIPT_FIREBASE_SENDER_ID`

本地也可以在未提交的 `android/local.properties` 中使用：

```properties
chillscript.firebase.apiKey=...
chillscript.firebase.appId=1:...:android:...
chillscript.firebase.projectId=...
chillscript.firebase.senderId=...
```

四项必须同时存在；任一缺失时，Firebase 初始化、设备注册和后台重试都会跳过。

## 3. 服务端发送配置

服务端需要：

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_EMAIL`
- `FCM_SERVICE_ACCOUNT_PRIVATE_KEY`
- `FCM_ANDROID_PACKAGE_NAME`（可选，默认 `com.sponteoai.chillscript`）

服务账号需要目标 Firebase 项目的 Firebase Cloud Messaging API Admin 权限。
私钥可以把换行保存为 `\n`，服务端会在运行时还原。若 Google Play 服务账号已获该
Firebase 权限，也可省略两项 `FCM_SERVICE_ACCOUNT_*`，代码会回退使用
`GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` 和 `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`。

缺少这些服务端变量时，APNs 仍按原逻辑工作；Android 发送会返回
`fcm_not_configured` 并进入有限次数重试，不会令通知 worker 崩溃。

## 4. 上架前验证

1. 安装 release 候选包并登录。
2. 启用周选题，确认 Android 13+ 只在用户确认后出现系统通知权限。
3. 从其他 App 导入视频，确认解释弹窗每个用户只出现一次。
4. 发送 `weekly_topics_ready`，确认后台通知使用本机语言，点击后打开周选题。
5. 发送带 `route=note` 和 `noteId` 的导入完成通知，确认同步后打开对应笔记。
6. 登出后确认当前安装已从服务端注销，并且不会继续收到该账号的通知。
