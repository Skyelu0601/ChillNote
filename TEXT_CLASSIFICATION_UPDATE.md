# 笔记标签流程更新

## ✅ 变更内容

- 移除「AI 推荐分类」：不再对文字/语音笔记做自动标签推荐
- 统一为「手动选择标签」：创建笔记后弹出标签选择器
- 新增「New Tag」：在选择器内创建自定义标签（名称 + 图标 + 颜色）

## 🚀 使用方式

### 文字笔记
1. 输入文字并点击发送
2. 标签选择器弹出
3. 选择标签后点击 **"Confirm"** 保存，或点击 **"Skip"** 直接保存

### 语音笔记
1. 录音并点击确认
2. 完成转录后弹出标签选择器
3. 选择标签后点击 **"Confirm"** 保存，或点击 **"Skip"** 直接保存

## ⚡ 接口变化

- `/ai/voice-note`：仅用于「转录 + 轻度润色」，返回 `{ text }`
- 不再调用 `/ai/gemini` 来做文本分类推荐

## 🔄 更新内容

### 修改文件
- `chillnote/Features/HomeView.swift` - 移除文本 AI 分类调用，改为直接弹出标签选择器
- `chillnote/Core/Components/CategorySelectorSheet.swift` - 移除 AI 建议区，新增 `New Tag`
- `chillnote/Services/GeminiService.swift` - 移除 `classifyText()`，简化 `transcribeAndPolish()`
- `server/src/index.ts` - `/ai/voice-note` 不再生成 categories

---

**更新时间**：2026-01-14  
**版本**：v1.2 - 手动标签 + 自定义标签创建  
**状态**：✅ 已更新
