import XCTest
@testable import chillnote

final class WeeklyTopicModelsTests: XCTestCase {
    func testSourceWithoutAvailabilityDefaultsToActive() throws {
        let source = try JSONDecoder().decode(
            WeeklyTopicSource.self,
            from: Data(#"""
            {
                "noteId":"note-1",
                "noteTitle":"A source",
                "platformName":null,
                "excerpt":"An excerpt"
            }
            """#.utf8)
        )

        XCTAssertEqual(source.resolvedAvailability, .active)
    }

    func testDeletedSourceAvailabilityDecodes() throws {
        let source = try JSONDecoder().decode(
            WeeklyTopicSource.self,
            from: Data(#"""
            {
                "noteId":"note-1",
                "noteTitle":"",
                "platformName":null,
                "excerpt":"",
                "availability":"deleted"
            }
            """#.utf8)
        )

        XCTAssertEqual(source.resolvedAvailability, .deleted)
    }
}
