package com.sponteoai.chillscript.ai

import android.content.Context
import android.content.ContextWrapper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class RecipeFavoritesTest {
    @Test
    fun favoritesPersistOrderAndReplacementWithoutRemovingAvailableSkills() {
        val prefix = "skill_test_${UUID.randomUUID()}_"
        val context = object : ContextWrapper(InstrumentationRegistry.getInstrumentation().targetContext) {
            override fun getSharedPreferences(name: String, mode: Int) = super.getSharedPreferences(prefix + name, mode)
        }
        try {
            val store = RecipeStore(context)
            assertEquals(BuiltInRecipes.all, store.installed.value)
            assertEquals(listOf("rewrite", "hook_generator", "caption_pack", "repurpose_pack"), store.favorites.value.map { it.id })
            val replacement = BuiltInRecipes.all.first { it.id !in store.favorites.value.map { favorite -> favorite.id } }
            store.toggle(replacement)
            assertEquals(4, store.favorites.value.size)
            val old = store.favorites.value[1]
            store.replaceFavorite(old, replacement)
            assertEquals(replacement.id, store.favorites.value[1].id)
            assertEquals(store.favorites.value, RecipeStore(context).favorites.value)
            store.favorites.value.toList().forEach(store::toggle)
            assertEquals(1, store.favorites.value.size)
            assertEquals(store.favorites.value, RecipeStore(context).favorites.value)
            store.toggle(store.favorites.value.single())
            assertEquals(1, store.favorites.value.size)
            assertEquals(BuiltInRecipes.all, store.installed.value)
            val custom = store.addCustom("Test skill", "Rewrite the input", "lightbulb.fill")
            assertEquals("lightbulb.fill", custom.systemIcon)
            assertEquals("lightbulb.fill", RecipeStore(context).installed.value.first { it.id == custom.id }.systemIcon)
            assertTrue(custom in store.installed.value)
            assertFalse(custom in store.favorites.value)
            store.replaceFavorite(store.favorites.value.single(), custom)
            assertEquals(listOf(custom), store.favorites.value)
            store.deleteCustom(custom)
            assertEquals(listOf("rewrite"), store.favorites.value.map { it.id })
            assertEquals(store.favorites.value, RecipeStore(context).favorites.value)
            assertFalse(custom in store.installed.value)
            context.getSharedPreferences("creator_skills", Context.MODE_PRIVATE).edit().putString("favorite_ids", "[]").commit()
            assertEquals(listOf("rewrite"), RecipeStore(context).favorites.value.map { it.id })
        } finally {
            context.getSharedPreferences("creator_skills", Context.MODE_PRIVATE).edit().clear().commit()
        }
    }
}
