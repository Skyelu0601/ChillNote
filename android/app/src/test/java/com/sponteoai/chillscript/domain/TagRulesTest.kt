package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.TagEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class TagRulesTest {
    @Test fun colorNormalizationMatchesIosRules() {
        assertEquals("#2F86FF", TagColors.normalize("2f86ff"))
        assertEquals(TagColors.Default, TagColors.normalize("not-a-color"))
    }

    @Test fun descendantsCannotBecomeParents() {
        val root = tag("root", null)
        val child = tag("child", "root")
        val grandchild = tag("grandchild", "child")
        val other = tag("other", null)

        assertEquals(listOf("other"), TagHierarchy.validParents("root", listOf(root, child, grandchild, other)).map { it.id })
    }

    private fun tag(id: String, parentId: String?) = TagEntity(
        id = id,
        userId = "user",
        name = id,
        colorHex = TagColors.Default,
        createdAt = "2026-07-13T00:00:00Z",
        updatedAt = "2026-07-13T00:00:00Z",
        lastUsedAt = "2026-07-13T00:00:00Z",
        parentId = parentId,
    )
}
