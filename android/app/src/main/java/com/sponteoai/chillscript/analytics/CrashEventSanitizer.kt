package com.sponteoai.chillscript.analytics

/** Allowlist crash diagnostics. Drop raw messages, breadcrumbs, locals and arbitrary event properties. */
internal object CrashEventSanitizer {
    private val contextKeys = setOf(
        "platform", "environment", "schema_version", "\$geoip_disable", "\$lib", "\$lib_version",
        "\$app_version", "\$app_build", "\$app_namespace", "\$app_name", "\$os", "\$os_name",
        "\$os_version", "\$device_type", "\$device_model", "\$device_manufacturer",
        "\$screen_width", "\$screen_height", "\$locale", "\$timezone", "\$session_id",
        "\$is_identified", "\$process_person_profile", "\$exception_level", "\$exception_handled",
    )
    private val frameKeys = setOf(
        "platform", "module", "function", "in_app", "lineno", "colno", "map_id",
        "instruction_addr", "image_addr", "symbol_addr", "method_synthetic",
    )

    fun sanitize(properties: Map<String, Any>): Map<String, Any> =
        scalars(properties, contextKeys).apply {
            put("crash_reporting_schema", 1)
            put("\$exception_list", objects(properties["\$exception_list"]).map { exception ->
                scalars(exception, setOf("type", "module", "thread_id")).apply {
                    put("value", "[redacted]")
                    put("mechanism", scalars(objectValue(exception["mechanism"]),
                        setOf("type", "handled", "synthetic", "exception_id", "parent_id")))
                    val stack = objectValue(exception["stacktrace"])
                    put("stacktrace", mapOf(
                        "type" to "raw",
                        "frames" to objects(stack["frames"]).map { frame ->
                            scalars(frame, frameKeys).apply {
                                for (key in listOf("filename", "package")) {
                                    basename(frame[key])?.let { put(key, it) }
                                }
                            }
                        },
                    ))
                }
            })
            if (properties.containsKey("\$debug_images")) {
                put("\$debug_images", objects(properties["\$debug_images"]).map { image ->
                    scalars(image, setOf("type", "debug_id", "code_id", "image_addr",
                        "image_size", "image_vmaddr", "arch")).apply {
                        for (key in listOf("code_file", "debug_file")) {
                            basename(image[key])?.let { put(key, it) }
                        }
                    }
                })
            }
        }

    private fun scalars(input: Map<*, *>, keys: Set<String>): MutableMap<String, Any> =
        keys.mapNotNull { key ->
            val value = input[key]
            if (value is String || value is Number || value is Boolean) key to value else null
        }.toMap().toMutableMap()

    private fun objectValue(value: Any?): Map<*, *> = value as? Map<*, *> ?: emptyMap<Any, Any>()
    private fun objects(value: Any?): List<Map<*, *>> =
        (value as? List<*>)?.mapNotNull { it as? Map<*, *> }.orEmpty()
    private fun basename(value: Any?): String? =
        (value as? String)?.substringBefore('?')?.substringBefore('#')
            ?.replace('\\', '/')?.substringAfterLast('/')?.takeIf { it.isNotEmpty() }
}
