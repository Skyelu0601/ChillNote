# ChillNote 测试指南

## 📋 目录
- [测试策略](#测试策略)
- [测试覆盖范围](#测试覆盖范围)
- [如何运行测试](#如何运行测试)
- [测试说明](#测试说明)
- [未来计划](#未来计划)

---

## 🎯 测试策略

ChillNote 采用**分层测试策略**，优先保证核心业务逻辑的正确性：

### 1. **单元测试（当前重点）** ⭐⭐⭐⭐⭐
- **位置**: `chillnoteTests/chillnoteTests.swift`
- **优先级**: 最高
- **目标覆盖率**: 70-80%（核心模块）
- **运行速度**: 毫秒级

### 2. **UI测试（规划中）** ⭐⭐⭐
- **位置**: `chillnoteUITests/`
- **优先级**: 中等
- **覆盖**: 3-5个核心用户流程
- **运行速度**: 秒/分钟级

### 3. **集成测试（规划中）** ⭐⭐⭐⭐
- Mock外部服务（Gemini API、语音识别）
- 测试模块间交互
- 数据持久化验证

---

## 📊 测试覆盖范围

### ✅ 已实现的测试

#### 1. **ChecklistMarkdown 解析器** (8个测试)
测试清单格式的解析和序列化功能：

| 测试名称 | 测试场景 | 验证点 |
|---------|---------|--------|
| `testChecklistMarkdownParsesEmptyItem` | 空清单项 | 正确解析空内容 |
| `testChecklistMarkdownParsesSingleUncheckedItem` | 单个未勾选项 | 状态和文本正确 |
| `testChecklistMarkdownParsesSingleCheckedItem` | 单个已勾选项 | 大小写兼容 |
| `testChecklistMarkdownParsesMultipleItems` | 多个清单项 | 顺序和状态 |
| `testChecklistMarkdownParsesWithNotes` | 带备注的清单 | 备注和项目分离 |
| `testChecklistMarkdownReturnsNilForPlainText` | 纯文本输入 | 返回nil（非清单） |
| `testChecklistMarkdownHandlesCapitalXAsChecked` | 大写X标记 | 兼容性 |

**关键功能覆盖**:
- ✅ 正则表达式解析
- ✅ 状态标记（ /x/X）
- ✅ 多行处理
- ✅ 边界条件

---

#### 2. **HTMLConverter 转换器** (17个测试)
测试Markdown到HTML的双向转换：

| 测试名称 | 测试场景 | 验证点 |
|---------|---------|--------|
| `testMarkdownToHTMLConvertsBoldText` | 粗体 | `**text**` → `<strong>` |
| `testMarkdownToHTMLConvertsItalicText` | 斜体 | `*text*` → `<em>` |
| `testMarkdownToHTMLConvertsInlineCode` | 行内代码 | \`code\` → `<code>` |
| `testMarkdownToHTMLConvertsHeading1/2/3` | 标题 | `#` → `<h1>` |
| `testMarkdownToHTMLConvertsUnorderedList` | 无序列表 | `-` → `<ul><li>` |
| `testMarkdownToHTMLConvertsOrderedList` | 有序列表 | `1.` → `<ol><li>` |
| `testMarkdownToHTMLConvertsCheckboxUnchecked` | 未勾选框 | `- [ ]` → 样式类 |
| `testMarkdownToHTMLConvertsCheckboxChecked` | 已勾选框 | `- [x]` → strikethrough |
| `testMarkdownToHTMLConvertsBlockquote` | 引用块 | `>` → `<blockquote>` |
| `testMarkdownToHTMLConvertsHorizontalRule` | 分隔线 | `---` → `<hr>` |
| `testMarkdownToHTMLEscapesHTMLEntities` | 转义字符 | `<>&` → `&lt;&gt;&amp;` |
| `testMarkdownToHTMLHandlesEmptyLines` | 空行处理 | 段落分隔 |
| `testHTMLToPlainTextExtractsText` | HTML到纯文本 | 去除标签 |

**关键功能覆盖**:
- ✅ 所有主要Markdown语法
- ✅ HTML实体转义
- ✅ 安全性（防XSS）
- ✅ 双向转换

---

#### 3. **Note 模型** (11个测试)
测试笔记核心数据模型：

| 测试名称 | 测试场景 | 验证点 |
|---------|---------|--------|
| `testNoteInitializesWithPlainText` | 纯文本初始化 | 格式标记正确 |
| `testNoteInitializesWithChecklistContent` | 清单内容初始化 | 自动识别格式 |
| `testNoteInitializesWithHTMLContent` | HTML内容初始化 | HTML格式处理 |
| `testNoteDisplayTextTruncatesLongContent` | 长文本截断 | 200字符+... |
| `testNoteDisplayTextDoesNotTruncateShortContent` | 短文本不截断 | 原样返回 |
| `testNoteMigrateToHTMLConvertsMarkdown` | Markdown迁移 | 转换为HTML |
| `testNoteMigrateToHTMLIsIdempotent` | 迁移幂等性 | 多次调用结果相同 |
| `testNoteMarkDeletedSetsDeletedAt` | 软删除 | 时间戳设置 |
| `testNoteEditableHTMLReturnsHTMLForHTMLFormat` | HTML编辑器内容 | 返回HTML |
| `testNoteEditableHTMLConvertsMarkdownForTextFormat` | Markdown编辑器内容 | 转换后返回 |

**关键功能覆盖**:
- ✅ 多种内容格式（text/checklist/HTML）
- ✅ 格式自动识别
- ✅ 内容迁移
- ✅ 显示文本生成
- ✅ 软删除机制

---

#### 4. **Tag 层级模型** (8个测试)
测试标签的树形结构：

| 测试名称 | 测试场景 | 验证点 |
|---------|---------|--------|
| `testTagInitializesWithDefaults` | 默认初始化 | 初始状态 |
| `testTagIsRootReturnsTrueForRootTag` | 根节点判断 | 无父节点 |
| `testTagIsRootReturnsFalseForChildTag` | 子节点判断 | 有父节点 |
| `testTagFullPathReturnsCorrectPath` | 完整路径 | "Work > AI > LLM" |
| `testTagAncestorsReturnsCorrectOrder` | 祖先链 | 从根到父的顺序 |
| `testTagAllDescendantsReturnsAllChildren` | 所有后代 | 递归查找 |
| `testTagIsAncestorReturnsTrue` | 祖先关系判断 | 正向验证 |
| `testTagIsAncestorReturnsFalse` | 非祖先关系 | 负向验证 |

**关键功能覆盖**:
- ✅ 父子关系建立
- ✅ 树形遍历（祖先/后代）
- ✅ 路径生成
- ✅ 关系判断

---

#### 5. **Date 扩展** (5个测试)
测试相对时间格式化：

| 测试名称 | 测试场景 | 期望输出 |
|---------|---------|---------|
| `testDateRelativeFormattedReturnsTimeForToday` | 今天 | "14:30" |
| `testDateRelativeFormattedReturnsYesterdayForYesterday` | 昨天 | "Yesterday 14:30" |
| `testDateRelativeFormattedReturnsWeekdayForThisWeek` | 本周 | "Monday 14:30" |
| `testDateRelativeFormattedReturnsMonthDayForThisYear` | 今年 | "Jan 10 14:30" |
| `testDateRelativeFormattedReturnsFullDateForOverAYear` | 一年前 | "2024/01/10" |

**关键功能覆盖**:
- ✅ 所有时间范围
- ✅ 格式正确性
- ✅ 边界条件

---

#### 6. **LanguageDetection** (3个测试)
测试语言识别功能：

| 测试名称 | 测试场景 | 验证点 |
|---------|---------|--------|
| `testLanguageDetectionReturnsChineseForChineseText` | 中文文本 | `zh-*` |
| `testLanguageDetectionReturnsEnglishForEnglishText` | 英文文本 | `en-*` |
| `testLanguageDetectionReturnsNilForEmptyText` | 空文本 | `nil` |

---

#### 7. **性能测试** (2个测试)
基准性能测试：

| 测试名称 | 测试场景 | 用途 |
|---------|---------|------|
| `testPerformanceMarkdownToHTML` | Markdown转换 | 性能基准 |
| `testPerformanceChecklistParsing` | 100项清单解析 | 性能基准 |

---

## 🚀 如何运行测试

### 方法1: Xcode GUI
1. 打开 `chillnote.xcodeproj`
2. 按 `⌘ + U` 运行所有测试
3. 或在测试导航器中点击单个测试

### 方法2: 命令行（推荐用于CI）

```bash
# 运行所有单元测试
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:chillnoteTests

# 运行单个测试类
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:chillnoteTests/chillnoteTests

# 运行特定测试方法
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:chillnoteTests/chillnoteTests/testNoteInitializesWithPlainText

# 快速运行（只看结果）
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:chillnoteTests \
  2>&1 | grep -A 5 "Test Suite"
```

### 方法3: 使用 xcrun

```bash
# 在特定模拟器上运行
xcrun simctl list devices available
xcrun xcodebuild test -scheme chillnote -destination 'id=<DEVICE_UUID>'
```

---

## 📈 测试统计

当前测试统计：
- **总测试数**: 54个
- **通过率**: 目标100%
- **代码覆盖率**: 
  - Models: ~80%
  - Utils: ~85%
  - Services: ~30%（部分依赖外部服务）
  
---

## 🧪 测试最佳实践

### 1. **命名规范**
```swift
func test[模块名][操作][预期结果]() {
    // 示例：testNoteInitializesWithPlainText
}
```

### 2. **AAA模式** (Arrange-Act-Assert)
```swift
func testExample() {
    // Arrange - 准备测试数据
    let note = Note(content: "Test")
    
    // Act - 执行操作
    note.markDeleted()
    
    // Assert - 验证结果
    XCTAssertNotNil(note.deletedAt)
}
```

### 3. **测试隔离**
- 每个测试独立运行
- 使用 `setUp()` 准备干净的环境
- 使用 `tearDown()` 清理资源

### 4. **使用内存数据库**
```swift
// SwiftData测试时使用内存模式
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
modelContainer = try ModelContainer(for: schema, configurations: [configuration])
```

---

## 🔜 未来测试计划

### 阶段2: UI测试 (1-2天)
- [ ] 笔记创建流程
- [ ] 笔记编辑和保存
- [ ] 标签添加和管理
- [ ] 语音录音流程
- [ ] 搜索和过滤

### 阶段3: Mock服务 (1-2天)
- [ ] GeminiService Mock
- [ ] SpeechRecognizer Mock
- [ ] 网络错误处理测试
- [ ] 离线同步测试

### 阶段4: 集成测试
- [ ] 端到端用户流程
- [ ] 数据持久化完整性
- [ ] 同步冲突解决
- [ ] AI标签生成流程

### 阶段5: 快照测试（可选）
- [ ] 关键UI组件视觉回归
- [ ] 使用 swift-snapshot-testing

---

## 🐛 已知限制

### 1. **SwiftData限制**
- 某些关系操作需要真实Context
- 级联删除测试较复杂

### 2. **异步测试**
- 需要使用 `expectation` 等待异步操作
- AI服务调用应使用Mock

### 3. **UI测试脆弱性**
- 依赖UI结构稳定
- 需要accessibility标识符

---

## 📚 相关资源

- [Apple Testing Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://www.swiftbysundell.com/articles/unit-testing-in-swift/)
- [SwiftData Testing Guide](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-test-swiftdata-apps)

---

## 🤝 贡献测试

添加新测试时，请确保：

1. ✅ 测试命名清晰
2. ✅ 包含正向和负向测试
3. ✅ 文档化特殊边界条件
4. ✅ 保持测试独立性
5. ✅ 更新本文档的覆盖范围表格

---

最后更新: 2026-01-22
测试覆盖模块: ChecklistMarkdown, HTMLConverter, Note, Tag, Date Extensions, LanguageDetection
