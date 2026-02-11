//
//  chillnoteIntegrationTests.swift
//  chillnoteTests
//
//  Created by Automation on 2026/1/22.
//

import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class chillnoteIntegrationTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var tagService: TagService!

    override func setUpWithError() throws {
        // 使用内存数据库进行快速、隔离的集成测试
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        
        // TagService 是单例，但我们的测试方法允许注入 Context，所以直接使用单例即可
        tagService = TagService.shared
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        tagService = nil
    }

    // MARK: - SwiftData Relationship Tests (数据完整性)
    
    /// 测试：删除标签时，关联的笔记**不应该**被删除
    func testDeletingTagDoesNotDeleteNotes() throws {
        // Arrange
        let note = Note(content: "Important Note", userId: "u1")
        let tag = Tag(name: "Work", userId: "u1")
        
        modelContext.insert(note)
        modelContext.insert(tag)
        
        // 建立关联
        note.tags.append(tag)
        try modelContext.save()
        
        // 验证关联建立成功
        XCTAssertEqual(note.tags.count, 1)
        XCTAssertEqual(tag.notes.count, 1)
        
        // Act - 软删除标签
        tag.deletedAt = Date()
        tag.updatedAt = tag.deletedAt ?? Date()
        try modelContext.save()
        
        // Assert - 验证标签没了，但笔记还在
        let notesCheck = try modelContext.fetch(FetchDescriptor<Note>())
        let activeTagsCheck = try modelContext.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil }))
        
        XCTAssertEqual(activeTagsCheck.count, 0, "活动标签应该被隐藏/删除")
        XCTAssertEqual(notesCheck.count, 1, "笔记应该保留")
        XCTAssertEqual(notesCheck.first?.content, "Important Note", "笔记内容应保持不变")
        let activeTagRelations = notesCheck.first?.tags.filter { $0.deletedAt == nil } ?? []
        XCTAssertEqual(activeTagRelations.count, 0, "笔记不应再关联任何活跃标签")
    }
    
    /// 测试：删除笔记时，关联的 ChecklistItems **应该** 级联删除
    func testChecklistItemCascadeDelete() throws {
        // Arrange
        let note = Note(content: "- [ ] Item 1\n- [ ] Item 2", userId: "u1")
        // 手动触发解析以生成 checkItems (因为逻辑在 init 或 syncContentStructure)
        // Note(content:) init 中会调用 parsing，所以此时 checklistItems 应该已经生成
        
        modelContext.insert(note)
        try modelContext.save()
        
        // 验证初始状态
        XCTAssertEqual(note.checklistItems.count, 2)
        
        // 确保 Item 确实存到了 context 中
        let itemsCheckBefore = try modelContext.fetch(FetchDescriptor<ChecklistItem>())
        XCTAssertEqual(itemsCheckBefore.count, 2, "Context 中应该有 2 个 Item")
        
        // Act - 删除笔记
        modelContext.delete(note)
        try modelContext.save()
        
        // Assert - 验证 Item 也都被删除了
        let notesCheck = try modelContext.fetch(FetchDescriptor<Note>())
        let itemsCheckAfter = try modelContext.fetch(FetchDescriptor<ChecklistItem>())
        
        XCTAssertEqual(notesCheck.count, 0, "笔记应该被删除")
        XCTAssertEqual(itemsCheckAfter.count, 0, "ChecklistItems 应该被级联删除")
    }

    // MARK: - TagService Logic Tests (业务逻辑集成)
    
    /// 测试：Cleanup 应该删除没有任何笔记的空标签
    func testCleanupEmptyTagsDeletesUnusedTags() throws {
        // Arrange
        let emptyTag = Tag(name: "Empty", userId: "u1")
        let usedTag = Tag(name: "Used", userId: "u1")
        let note = Note(content: "Note", userId: "u1")
        
        modelContext.insert(emptyTag)
        modelContext.insert(usedTag)
        modelContext.insert(note)
        
        note.tags.append(usedTag)
        try modelContext.save()
        
        // Act
        tagService.cleanupEmptyTags(context: modelContext)
        
        // Assert
        let activeTags = try modelContext.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil }))
        XCTAssertEqual(activeTags.count, 1)
        XCTAssertEqual(activeTags.first?.name, "Used")
        
        let deletedTags = try modelContext.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt != nil }))
        XCTAssertEqual(deletedTags.count, 1, "空标签应被软删除以便同步墓碑")
    }
    
    /// 测试：Cleanup **不应该** 删除有活跃笔记的标签
    func testCleanupEmptyTagsPreservesTagsWithActiveNotes() throws {
        // Arrange
        let tag = Tag(name: "Important", userId: "u1")
        let note = Note(content: "My Data", userId: "u1")
        
        modelContext.insert(tag)
        modelContext.insert(note)
        
        note.tags.append(tag)
        try modelContext.save()
        
        // Act
        tagService.cleanupEmptyTags(context: modelContext)
        
        // Assert
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.name, "Important")
    }
    
    /// 测试：Cleanup **应该** 删除那些只有软删除笔记的标签
    func testCleanupEmptyTagsDeletesTagsWithOnlySoftDeletedNotes() throws {
        // Arrange
        let tag = Tag(name: "Ghost Tag", userId: "u1")
        let note = Note(content: "Deleted Note", userId: "u1")
        
        modelContext.insert(tag)
        modelContext.insert(note)
        
        note.tags.append(tag)
        
        // 软删除笔记
        note.markDeleted()
        try modelContext.save()
        
        // Act
        tagService.cleanupEmptyTags(context: modelContext)
        
        // Assert
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1, "标签应保留墓碑记录以支持同步")
        XCTAssertNotNil(tags.first?.deletedAt, "只有软删除笔记关联时，标签应被软删除")
    }
    
    /// 测试：软删除笔记过滤逻辑验证
    func testFetchActiveNotesExcludesSoftDeleted() throws {
        // Arrange
        let activeNote = Note(content: "Active", userId: "u1")
        let deletedNote = Note(content: "Deleted", userId: "u1")
        deletedNote.markDeleted()
        
        modelContext.insert(activeNote)
        modelContext.insert(deletedNote)
        try modelContext.save()
        
        // Act
        // 模拟 DataService 或 View 中的过滤逻辑
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil })
        let fetchedNotes = try modelContext.fetch(descriptor)
        
        // Assert
        XCTAssertEqual(fetchedNotes.count, 1)
        XCTAssertEqual(fetchedNotes.first?.content, "Active")
    }
}
