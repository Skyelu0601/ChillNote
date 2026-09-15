# ChillScript 1.2.16 发布记录

两端均从 **1.2.15 → 1.2.16**，已提交商店审核。本次未 commit 或 push，保留全部原有工作区修改。

| 平台 | 构建号 | 最终确认 |
| --- | --- | --- |
| iOS | Build 2 | App Store Connect 已接受二进制；VALID；WAITING_FOR_REVIEW |
| Android | versionCode 16 | Google Play Production 提交成功；completed；rollout 1.0；changes_not_sent_for_review=false |

## 审核与发布设置

- iOS 更新说明：`fix known issues`，14 个语言已回读验证。
- iOS 出口合规：`None`，服务端 `usesNonExemptEncryption=false`。
- iOS 本次未设置或修改自动发布；后台现有设置是 `AFTER_APPROVAL`，审核通过后自动发布。
- Android 审核通过后自动向 100% 用户发布。
- 未上传标题、描述、关键词、截图等其他商店元数据。

## 构建产物

- [iOS IPA](/tmp/chillscript-simple-release-1.2.16/ChillScript-1.2.16.ipa)
- [Android AAB](/Users/luwenting/development/chillnote/android/app/build/outputs/bundle/release/app-release.aab)
- [机器可读发布回执](mobile-1.2.16-release.json)

iOS 归档成功后，首次 IPA 导出因本机缺少发行签名证书失败；使用原 App Store Connect 凭据和原团队自动签名，从同一归档重新导出成功，没有重建或修改业务代码。

## 崩溃符号

用户明确授权后，两端符号均已在 PostHog US 项目 596105 确认 `has_uploaded_file=true`、`failure_reason=null`。

- Android mapping ref：`9e3253f1-e8f9-3017-a31a-c911b40cba71`，与已提交 AAB 内映射逐字节一致，关联 `1.2.16+16`。
- iOS 主 App、分享扩展、Widget、GoMarketMe 四组 UUID 均与此归档对应；未重复上传已存在的相同符号。
- iOS 主 App 的 PostHog release 元数据为 null，其余组件保留旧 release 关联；精确 UUID 符号文件已齐备。本次未触发生产崩溃做端到端验证。

## 配套部署与数据库

- 后端仅补上线 pt-BR / pt-PT 导入标题模块，旧 release 保留可回退。详见 [后端回执](backend-20260912-pt-localization.json)。
- 官网隐私说明已部署到 https://www.chillnoteai.com/privacy ，生产回读确认新增崩溃诊断说明与链接生效。Vercel deployment：`dpl_C4cFeasdTpgHfzTmG9oqDjuyTxnD`，READY。
- 数据库 29 个迁移均已执行，最新为 `20260909090000_app_notifications`；没有待执行迁移或 Edge Functions，无数据库变更。

## 实际验证

- iOS：版本/构建号一致性、差异格式检查、通用 Simulator build、Release archive、签名 IPA 导出、App Store 状态/构建/合规/更新说明回读通过。
- Android：Release 签名预检、R8、必要 lintVital、jarsigner、版本字段差异和 AAB/mapping 一致性通过。
- 后端：构建、84 项本地测试、4 项生产语言测试、生产健康与鉴权检查通过。
- 官网：类型检查、本地与远程生产构建、隐私页面与链接检查通过；部署后短时检查未发现 runtime errors。
- 本次未额外运行移动端单元测试、设备/模拟器运行测试，也未运行 Android 完整 Lint、Debug 构建或本地化检查。未执行真实账号视频导入端到端测试。
