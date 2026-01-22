# ChillNote 测试快速参考

## 🚀 快速运行测试

### 推荐命令（使用 iPhone 16 模拟器）
```bash
# 运行所有单元测试
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:chillnoteTests

# 只查看测试结果（过滤噪音）
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:chillnoteTests \
  2>&1 | grep -E "(Test Suite|Test Case|passed|failed)"
```

### Xcode中运行
1. 打开 `chillnote.xcodeproj`
2. `⌘ + U` 运行所有测试
3. 或导航到测试文件，点击左侧的▶️按钮

---

## 📊 当前测试覆盖（54个测试）

### ChecklistMarkdown (8个)
- ✅ 空项解析
- ✅ 单项解析（勾选/未勾选）
- ✅ 多项解析
- ✅ 带备注解析
- ✅ 纯文本返回nil
- ✅ 大小写兼容

### HTMLConverter (17个)
- ✅ Markdown格式转换（粗体、斜体、代码）
- ✅ 标题（h1, h2, h3）
- ✅ 列表（有序、无序、清单）
- ✅ 引用和分隔线
- ✅ HTML实体转义
- ✅ HTML转纯文本

### Note模型 (11个)
- ✅ 多种格式初始化
- ✅ 显示文本截断
- ✅ HTML迁移
- ✅ 软删除
- ✅ 编辑器内容获取

### Tag模型 (8个)
- ✅ 层级关系
- ✅ 路径生成
- ✅ 祖先/后代查找
- ✅ 关系判断

### Date扩展 (5个)
- ✅ 相对时间格式化
- ✅ 所有时间范围

### 其他 (5个)
- ✅ 语言识别
- ✅ 性能基准

---

## 🐛 测试失败快速诊断

### 常见问题

#### 1. 模拟器找不到
```bash
# 查看可用模拟器
xcrun simctl list devices available | grep iPhone

# 使用实际存在的模拟器
xcodebuild test \
  -scheme chillnote \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:chillnoteTests
```

#### 2. Schema找不到
```bash
# 列出所有scheme
xcodebuild -list -project chillnote.xcodeproj

# 确保使用正确的scheme名称
```

#### 3. SwiftData错误
确保测试使用内存数据库：
```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
```

#### 4. 异步测试超时
增加timeout时间：
```swift
let expectation = self.expectation(description: "...")
wait(for: [expectation], timeout: 10.0) // 增加到10秒
```

---

## 📝 添加新测试的模板

### 单元测试模板
```swift
func test[Module][Action][ExpectedResult]() throws {
    // Arrange - 准备测试数据
    let input = "test data"
    
    // Act - 执行操作
    let result = MyClass.method(input)
    
    // Assert - 验证结果
    XCTAssertEqual(result, expectedValue)
    XCTAssertTrue(condition)
    XCTAssertNotNil(object)
}
```

### 异步测试模板
```swift
func testAsyncOperation() async throws {
    let result = try await service.asyncMethod()
    XCTAssertNotNil(result)
}
```

### 性能测试模板
```swift
func testPerformance[Operation]() throws {
    measure {
        // 要测量的代码
        _ = MyClass.expensiveOperation()
    }
}
```

---

## ✅ 测试检查清单

添加新测试时检查：

- [ ] 测试命名清晰（test+模块+操作+结果）
- [ ] 包含正向测试（happy path）
- [ ] 包含负向测试（edge cases）
- [ ] 测试独立（不依赖其他测试）
- [ ] 使用断言验证结果
- [ ] 清理测试数据（tearDown）
- [ ] 更新文档（TESTING_GUIDE.md）

---

## 🎯 下一步测试优先级

### 高优先级
1. [ ] DataService的CRUD操作
2. [ ] Note的SwiftData关系测试
3. [ ] Tag的级联删除测试

### 中优先级
4. [ ] SyncMapper逻辑测试
5. [ ] 更多边界条件测试

### 低优先级（需要Mock）
6. [ ] GeminiService集成（需要Mock）
7. [ ] 语音识别流程（需要Mock）

---

最后更新: 2026-01-22
当前测试数: 54
