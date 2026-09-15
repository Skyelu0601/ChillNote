import Foundation

/// Keeps symbolication metadata; raw reasons, breadcrumbs, locals and arbitrary properties never leave the app.
enum CrashEventSanitizer {
    private static let contextKeys: Set<String> = [
        "platform", "environment", "schema_version", "$geoip_disable", "$lib", "$lib_version",
        "$app_version", "$app_build", "$app_namespace", "$app_name", "$os", "$os_name",
        "$os_version", "$device_type", "$device_model", "$device_manufacturer",
        "$screen_width", "$screen_height", "$locale", "$timezone", "$session_id",
        "$is_identified", "$process_person_profile", "$exception_level", "$exception_handled"
    ]
    private static let frameKeys: Set<String> = [
        "platform", "module", "function", "in_app", "lineno", "colno", "map_id",
        "instruction_addr", "image_addr", "symbol_addr", "method_synthetic"
    ]

    static func sanitize(_ properties: [String: Any]) -> [String: Any] {
        var result = scalars(properties, keys: contextKeys)
        result["crash_reporting_schema"] = 1
        result["$exception_list"] = objects(properties["$exception_list"]).map { exception in
            var item = scalars(exception, keys: ["type", "module", "thread_id"])
            item["value"] = "[redacted]"
            item["mechanism"] = scalars(exception["mechanism"] as? [String: Any] ?? [:],
                keys: ["type", "handled", "synthetic", "exception_id", "parent_id"])
            let stack = exception["stacktrace"] as? [String: Any] ?? [:]
            item["stacktrace"] = [
                "type": "raw",
                "frames": objects(stack["frames"]).map { frame in
                    var clean = scalars(frame, keys: frameKeys)
                    for key in ["filename", "package"] { clean[key] = basename(frame[key]) }
                    return clean
                }
            ]
            return item
        }
        if properties["$debug_images"] != nil {
            result["$debug_images"] = objects(properties["$debug_images"]).map { image in
                var clean = scalars(image, keys: ["type", "debug_id", "code_id", "image_addr",
                    "image_size", "image_vmaddr", "arch"])
                for key in ["code_file", "debug_file"] { clean[key] = basename(image[key]) }
                return clean
            }
        }
        return result
    }

    private static func scalars(_ input: [String: Any], keys: Set<String>) -> [String: Any] {
        input.filter { keys.contains($0.key) && ($0.value is String || $0.value is NSNumber) }
    }

    private static func objects(_ value: Any?) -> [[String: Any]] { value as? [[String: Any]] ?? [] }

    private static func basename(_ value: Any?) -> String? {
        guard let path = value as? String else { return nil }
        let name = path.components(separatedBy: "?")[0].components(separatedBy: "#")[0]
            .replacingOccurrences(of: "\\", with: "/").components(separatedBy: "/").last
        return name?.isEmpty == false ? name : nil
    }
}
