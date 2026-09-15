package com.sponteoai.chillscript.analytics

import org.junit.Assert.*
import org.junit.Test

class CrashEventSanitizerTest {
    @Test fun stripsSensitiveContentButKeepsGroupingAndSymbolication() {
        val secret = "private-note-email-token"
        val result = CrashEventSanitizer.sanitize(mapOf(
            "environment" to "production", "\$exception_level" to "fatal",
            "note" to secret, "\$exception_steps" to listOf(secret),
            "\$exception_list" to listOf(mapOf(
                "type" to "IllegalStateException", "value" to secret,
                "mechanism" to mapOf("handled" to false, "type" to "generic", "data" to secret),
                "stacktrace" to mapOf("frames" to listOf(mapOf(
                    "module" to "com.sponteoai.chillscript.MainActivity", "function" to "onCreate",
                    "filename" to "/Users/$secret/MainActivity.kt", "lineno" to 42,
                    "map_id" to "build-map-uuid", "vars" to mapOf("token" to secret),
                ))),
            )),
            "\$debug_images" to listOf(mapOf("debug_id" to "image-uuid", "type" to "elf",
                "code_file" to "/data/$secret/libapp.so", "image_addr" to "0x1000")),
        ))
        assertFalse(result.toString().contains(secret))
        assertEquals("fatal", result["\$exception_level"])
        assertEquals("production", result["environment"])
        val exception = (result["\$exception_list"] as List<*>).single() as Map<*, *>
        assertEquals("IllegalStateException", exception["type"])
        assertEquals("[redacted]", exception["value"])
        assertEquals(false, (exception["mechanism"] as Map<*, *>)["handled"])
        val frame = ((exception["stacktrace"] as Map<*, *>)["frames"] as List<*>).single() as Map<*, *>
        assertEquals("build-map-uuid", frame["map_id"])
        assertEquals("MainActivity.kt", frame["filename"])
        assertEquals(42, frame["lineno"])
        val image = (result["\$debug_images"] as List<*>).single() as Map<*, *>
        assertEquals("image-uuid", image["debug_id"])
        assertEquals("libapp.so", image["code_file"])
    }

    @Test fun toleratesMalformedOptionalSdkFields() {
        val result = CrashEventSanitizer.sanitize(mapOf("\$exception_list" to "bad", "\$debug_images" to 42))
        assertEquals(emptyList<Any>(), result["\$exception_list"])
        assertEquals(emptyList<Any>(), result["\$debug_images"])
    }
}
