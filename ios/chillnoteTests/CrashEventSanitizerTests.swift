import XCTest
@testable import chillnote

final class CrashEventSanitizerTests: XCTestCase {
    func testStripsSensitiveContentAndPreservesSymbolication() throws {
        let secret = "private-note-email-token"
        let result = CrashEventSanitizer.sanitize([
            "environment": "production", "$exception_level": "fatal",
            "note": secret, "$exception_steps": [secret],
            "$exception_list": [[
                "type": "SIGABRT", "value": secret,
                "mechanism": ["handled": false, "type": "signal", "data": secret],
                "stacktrace": ["frames": [[
                    "function": "crashTest", "instruction_addr": "0x1234", "image_addr": "0x1000",
                    "package": "/Users/\(secret)/chillnote.app/chillnote", "vars": ["token": secret]
                ]]]
            ]],
            "$debug_images": [["type": "macho", "debug_id": "image-uuid",
                "image_addr": "0x1000", "code_file": "/Users/\(secret)/chillnote.app/chillnote"]]
        ])
        let json = String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        XCTAssertFalse(json.contains(secret))
        XCTAssertEqual(result["$exception_level"] as? String, "fatal")
        XCTAssertEqual(result["environment"] as? String, "production")
        let exception = try XCTUnwrap((result["$exception_list"] as? [[String: Any]])?.first)
        XCTAssertEqual(exception["type"] as? String, "SIGABRT")
        XCTAssertEqual(exception["value"] as? String, "[redacted]")
        XCTAssertEqual((exception["mechanism"] as? [String: Any])?["handled"] as? Bool, false)
        let stack = try XCTUnwrap(exception["stacktrace"] as? [String: Any])
        let frame = try XCTUnwrap((stack["frames"] as? [[String: Any]])?.first)
        XCTAssertEqual(frame["instruction_addr"] as? String, "0x1234")
        XCTAssertEqual(frame["package"] as? String, "chillnote")
        let image = try XCTUnwrap((result["$debug_images"] as? [[String: Any]])?.first)
        XCTAssertEqual(image["debug_id"] as? String, "image-uuid")
        XCTAssertEqual(image["code_file"] as? String, "chillnote")
    }

    func testMalformedOptionalSDKFieldsDoNotCrashTheReporter() {
        let result = CrashEventSanitizer.sanitize(["$exception_list": "bad", "$debug_images": 42])
        XCTAssertEqual((result["$exception_list"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual((result["$debug_images"] as? [[String: Any]])?.count, 0)
    }
}
