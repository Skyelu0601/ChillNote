# ChillNote App Store 最终合规报告（美国）

**版本**: v1.0  
**日期**: 2026-02-05  
**范围**: 客户端、后端、隐私与订阅链路、App Store 提交材料  
**审查基准**: Apple App Store Review Guidelines（1-5）

## 1. 结论摘要
- **总体结论**: 已消除 P1/P2/P3 风险项，达到上架审核要求的合规基线。
- **关键改动**: 订阅披露补全、收据验证落地、隐私政策与本地录音存储一致化、移除 Reflection 相关功能与文案。
- **风险状态**: P1/P2/P3 均已修复。无新增高风险。

## 2. 指南对照矩阵（摘要）
> 详细证据见下方“证据与定位”。

### 1 Safety
- 1.1/1.4.1（误导性健康/治疗承诺）: **通过**
  - 相关文案已移除/改写，避免“治疗/治愈/治疗师”暗示。

### 2 Performance
- 2.5（权限与后台模式）: **通过**
  - 仅麦克风权限；后台音频模式用于录音流程。
- 2.3（元数据准确性）: **通过（需与 App Store Connect 文案一致）**

### 3 Business
- 3.1.1（IAP）: **通过**
  - 订阅校验改为 Apple 收据验证（生产+沙盒）。
- 3.1.2（订阅披露）: **通过**
  - 已补全自动续订/扣费/取消说明。
- 3.1.2(a)（Sign in with Apple）: **通过**

### 4 Design
- 4.0/4.2: **通过**
  - 产品功能完整、界面结构清晰。

### 5 Legal
- 5.1.1（隐私）: **通过**
  - 隐私政策已明确本地临时音频存储与自动清理。

## 3. 风险修复清单（P1/P2/P3）
### P1（已修复）
1. **订阅披露不完整**
   - 处理: 增加 Apple 要求的自动续订/扣费/取消说明。
   - 证据: `chillnote/Features/SubscriptionView.swift`

2. **隐私政策与本地录音存储不一致**
   - 处理: 政策与应用内提示同步声明本地临时存储与 7 天清理策略。
   - 证据: `docs/compliance/legal/PRIVACY_POLICY.md`, `website/privacy.html`, `chillnote/Features/SettingsView.swift`

### P2（已修复）
1. **订阅后端验证缺失**
   - 处理: 实装 `verifyReceipt` + sandbox fallback，基于 Apple 回执判定有效期。
   - 证据: `server/src/index.ts`, `chillnote/Services/StoreService.swift`

2. **医疗/心理暗示文案**
   - 处理: 移除/改写相关措辞。
   - 证据: `docs/product/DESIGN_PHILOSOPHY.md`, `chillnote/Features/AboutView.swift`, `chillnote/Features/SettingsView.swift`

### P3（已修复）
1. **隐私政策占位符**
   - 处理: 补齐日期与官网链接。
   - 证据: `docs/compliance/legal/PRIVACY_POLICY.md`

2. **后端文档与实现不一致**
   - 处理: 移除未实现的上传接口描述。
   - 证据: `server/README.md`

## 4. 证据与定位（关键文件）
- 订阅披露: `chillnote/Features/SubscriptionView.swift`
- 订阅校验: `server/src/index.ts`, `chillnote/Services/StoreService.swift`
- 隐私政策: `docs/compliance/legal/PRIVACY_POLICY.md`, `website/privacy.html`
- 应用内隐私提示: `chillnote/Features/SettingsView.swift`
- 文案合规: `docs/product/DESIGN_PHILOSOPHY.md`, `chillnote/Features/AboutView.swift`
- Reflection 相关 recipes 已移除: `chillnote/Models/AgentRecipe.swift`

## 5. App Store 提交材料建议（需准备）
- 应用描述需避免健康/治疗承诺，强调“记录/整理/反思”。
- 截图建议包含: 录音页、AI 整理、订阅页、设置页（含隐私/删除账号入口）。
- 审核备注建议包含:
  - 测试账号（Apple/Google/Email OTP）
  - 订阅测试流程（IAP Sandbox）
  - 关键路径说明（录音 → 转写 → 笔记）

## 6. 结论
当前代码与文案符合 App Store Review Guidelines 的合规基线，可进入提交审核流程。建议在提交前完成一次端到端复测（见复测结果表）。
