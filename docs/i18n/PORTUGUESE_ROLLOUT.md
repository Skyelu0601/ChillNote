# 葡萄牙语交付与发布记录

日期：2026-09-08。产品：ChillScript。

## 语言与覆盖

| 范围 | 巴西 | 葡萄牙 |
| --- | --- | --- |
| iOS 主 App、Widget、分享扩展 | pt-BR | pt-PT |
| iOS 权限说明 | pt-BR.lproj | pt-PT.lproj |
| Android 资源 | values-pt（通用葡语采用巴西用语） | values-pt-rPT |
| Android 系统语言选项 | pt | pt-PT |
| App Store / Google Play | pt-BR | pt-PT |
| 服务端导入笔记固定标题 | pt-BR | pt-PT |

- iOS：每种地区语言覆盖全部 998 个 key，其中 7 个采用复数结构。权限说明每种语言 4 条。
- Android：每种地区语言覆盖全部 672 个普通字符串和 9 个复数资源。品牌名、平台名、格式标记与少量通用术语保留原样。
- iOS 翻译工具增加两种葡语目标语言。两端语音识别原本已支持 Portuguese，保留原有 `pt` 提示，不迁移已有偏好。
- 推送通过移动端资源 key 本地化，无需新增独立服务端推送文案。
- 导入服务识别 `pt`、`pt-BR`、`pt-PT`、大小写及下划线变体；葡萄牙、安哥拉等地区使用 pt-PT 固定标题，其余葡语默认 pt-BR。原始转录语言不强制翻译。
- iOS 历史笔记作者解析兼容 `Autor desconhecido`，不把“未知作者”占位符展示为真实作者。
- 更新两端语言校验与 iOS 整理工具的必需语言列表；后续新增词条不能遗漏葡语。
- 没有更改应用 ID、商品 ID、数据库字段、线上域名或用户已有版本号修改。

## ASO 文字

已写入：

- `store/app-store/fastlane/metadata/pt-BR/`、`pt-PT/`：名称、副标题、关键词、推广文案、描述、版本更新说明、隐私/支持/营销链接。
- `store/google-play/fastlane/metadata/listing/pt-BR/`、`pt-PT/`：标题、短描述、完整描述、默认更新说明。

| 字段 | pt-BR | pt-PT |
| --- | --- | --- |
| App Store 名称 | ChillScript Ideias de conteúdo | ChillScript Ideias de conteúdo |
| App Store 名称长度 / 30 | 30 | 30 |
| 副标题 | Do vídeo viral ao novo post | Do vídeo viral ao novo post |
| 副标题长度 / 30 | 27 | 27 |
| 关键词长度 / 100 | 98 | 99 |
| Google Play 短描述长度 / 80 | 75 | 73 |

App Store 三字段参照现有英语、西语、法语、德语版本改写：标题统一突出“内容灵感”，副标题表达“从爆款视频到新帖子”，关键词补充平台名、转录、摘要、提词器、开场钩子、改写、脚本与 IA。巴西使用 `teleprompter` / `roteiro`，葡萄牙使用 `teleponto` / `guião`。巴西字段为适应长度去掉较宽泛的 `texto`。三个字段没有重复的完整词，关键词内部没有重复词。

此轮只调整 App Store 三字段，Google Play 标题及短描述保持原稿。

关键词是基于产品能力与当地商店用语的初版，不代表已测得搜索量、难度或排名。
巴西用语参考：[巴西 App Store 的 Teleprompter 开发者页面](https://apps.apple.com/br/app/teleprompter-gravador-roteiro/id6745204709)；葡萄牙用语参考：[葡萄牙 App Store 的 Detail 开发者页面](https://apps.apple.com/pt/app/detail-editor-v%C3%ADdeo-com-ia/id1673518618)。没有复制竞品描述，也没有承诺其功能。

## 截图与媒体：仍需完成

已生成两平台各 2 套、每套 5 张，共 20 张宣传标题本地化草稿：

- App Store：`store/app-store/screenshot/app_store_preview_draft/pt-BR/`、`pt-PT/`。
- Google Play：`store/google-play/screenshots/portuguese-draft/`，`previews/` 有联系表。

**这些草稿的界面底图仍为已有英文截图，尚不是完整葡萄牙语商店截图。** 未将草稿接入 Fastlane 正式截图上传目录。正式上架前，应在葡语 App 中截取真实界面，替换底图并复查排版。现有入门演示视频中的固化界面画面也没有重新录制；视频中的原始创作者内容无需因界面语言而改写。

生成工具已加入葡语文案；App Store 生成器增加 `--locale`，可只生成目标语言，不覆盖其他语言作品。

## 验证

- `python3 scripts/i18n/lint_i18n.py`：通过。
- `python3 android/scripts/validate_localizations.py`：通过。
- `python3 -m unittest discover -s android/scripts -p 'test_*.py'`：28 项通过。
- iOS 通用模拟器构建：通过，主 App、Widget、分享扩展的两种葡语均已打包；主 App 权限说明已打包。
- Android `assembleDebug`：通过。
- 服务端 `npm run build`：通过；`node --import tsx --test src/linkImportLocalization.test.ts`：4 项通过。使用直接加载方式避开本机沙箱对 tsx CLI IPC 的限制。
- Google Play 本地元数据校验：通过，涵盖英语及新增葡语文字；既有 9 套正式截图保持不变。
- 新增商店字段长度及 20 张草稿图片尺寸检查：通过。抽查草稿标题无裁切，底图的英文已标明。
- iOS 标准测试尝试被已有的 `NoteDetailViewModelTests.swift:194` 编译错误阻塞：创建 `NoteAISkillPreview` 时缺少 `analyticsRunID`，随后出现类型推断错误。该文件未在本次修改。定向验证临时通过构建参数 `EXCLUDED_SOURCE_FILE_NAMES=NoteDetailViewModelTests.swift` 排除该文件，不修改其源码；随后在已启动模拟器上以 `-parallel-testing-enabled NO` 运行 `QuickCaptureImportServiceTests`，16 项全部通过（含新增葡语作者用例）。
- 尚未进行两端逐屏真机排版验收、真实语音/AI 请求、商店转化率实验。

## 发布边界

初次开发交付为本地实现和素材准备；后续已按用户授权，将确认后的葡语标题、副标题、关键词上传至 App Store Connect 的 **1.2.13** 草稿。两种葡语全部字段均已回读匹配，其他语言及其他字段保持原状。上传记录见 `store/app-store/reports/portuguese-metadata-1.2.13-upload.json`。**版本仍为待提交状态，本次未提交审核、上传二进制/截图或部署服务端**。服务端新标题须部署后才对线上导入生效；移动端语言支持须随新版本发布。公开官网及其法律页面未新增葡语站点，商店链接继续使用现有有效页面。

`store/app-store` 是独立 Git 工作区，主仓库忽略该目录。发布或提交时，需要在该工作区单独纳入新增葡语元数据和截图生成器改动，不能只提交主仓库。

## 1.2.13 全语言推广与更新说明

已按用户授权更新并上传商店全部 14 个语言／地区的 `promotionalText` 与 `whatsNew`，共 28 个字段，回读全部匹配。推广文案突出“将保存的视频转为下一条内容”，更新说明介绍新增巴西及葡萄牙葡语支持。没有声称新增未经核实的功能或性能改善。版本仍为待提交审核。

完整文案：`store/app-store/reports/release-copy-1.2.13.md`。上传回执：`store/app-store/reports/release-copy-1.2.13-upload.json`。

## iOS 1.2.13 简单发布结果

版本由 1.2.12 升至 1.2.13，Build 保持 2。正式安装包已上传、处理通过并于 2026-09-08 提交审核，回读状态为 `WAITING_FOR_REVIEW`。出口合规已设为 None（`usesNonExemptEncryption=false`）。本次跳过更新说明和全部元数据上传，14 个地区的版本文案回读与发布前完全一致。没有修改商店已有发布方式：`AFTER_APPROVAL`（审核通过后自动发布）。没有 commit 或 push。

本次本地化检查、模拟器构建、Release 归档导出、分发签名及 IPA 葡语资源核对通过；未重跑单元测试。正式安装包位于 `/tmp/chillscript-simple-release-1.2.13/ChillScript-1.2.13.ipa`，回执位于 `store/app-store/reports/simple-ios-release-1.2.13.json`。本节为最新发布状态，前述待提交状态是元数据上传时的记录。
