package com.sponteoai.chillscript.ai

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.util.UUID

class RecipeStore(context: Context) {
    private val preferences = context.getSharedPreferences("creator_skills", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }
    private val mutableInstalled = MutableStateFlow(loadInstalled())
    val installed: StateFlow<List<AgentRecipe>> = mutableInstalled.asStateFlow()

    val available: List<AgentRecipe>
        get() = BuiltInRecipes.all + loadCustom()

    init {
        if (!preferences.contains(KEY_INSTALLED_IDS)) {
            saveInstalledIds(BuiltInRecipes.defaultIds)
            mutableInstalled.value = loadInstalled()
        }
    }

    fun toggle(recipe: AgentRecipe) {
        val ids = mutableInstalled.value.mapTo(mutableSetOf()) { it.id }
        if (!ids.add(recipe.id)) ids.remove(recipe.id)
        saveInstalledIds(ids)
        mutableInstalled.value = loadInstalled()
    }

    fun addCustom(name: String, prompt: String): AgentRecipe {
        val recipe = AgentRecipe(
            id = "custom_${UUID.randomUUID()}",
            name = name.trim(),
            description = "Custom skill",
            prompt = prompt.trim(),
            category = RecipeCategory.SHAPE,
            isCustom = true,
        )
        val custom = loadCustom() + recipe
        preferences.edit().putString(KEY_CUSTOM, json.encodeToString(ListSerializer(AgentRecipe.serializer()), custom)).apply()
        saveInstalledIds(mutableInstalled.value.mapTo(mutableSetOf()) { it.id } + recipe.id)
        mutableInstalled.value = loadInstalled()
        return recipe
    }

    fun deleteCustom(recipe: AgentRecipe) {
        if (!recipe.isCustom) return
        val custom = loadCustom().filterNot { it.id == recipe.id }
        preferences.edit().putString(KEY_CUSTOM, json.encodeToString(ListSerializer(AgentRecipe.serializer()), custom)).apply()
        saveInstalledIds(mutableInstalled.value.mapTo(mutableSetOf()) { it.id }.apply { remove(recipe.id) })
        mutableInstalled.value = loadInstalled()
    }

    fun clearUserData() {
        preferences.edit().clear().apply()
        saveInstalledIds(BuiltInRecipes.defaultIds)
        mutableInstalled.value = loadInstalled()
    }

    private fun loadInstalled(): List<AgentRecipe> {
        val all = available.associateBy { it.id }
        val ids = preferences.getStringSet(KEY_INSTALLED_IDS, BuiltInRecipes.defaultIds).orEmpty()
        return ids.mapNotNull(all::get).sortedBy { recipe ->
            listOf("hook_generator", "caption_pack", "rewrite", "repurpose_pack").indexOf(recipe.id).let { if (it < 0) Int.MAX_VALUE else it }
        }
    }

    private fun loadCustom(): List<AgentRecipe> = runCatching {
        json.decodeFromString(ListSerializer(AgentRecipe.serializer()), preferences.getString(KEY_CUSTOM, "[]") ?: "[]")
    }.getOrDefault(emptyList())

    private fun saveInstalledIds(ids: Set<String>) {
        preferences.edit().putStringSet(KEY_INSTALLED_IDS, ids).apply()
    }

    private companion object {
        const val KEY_INSTALLED_IDS = "installed_ids"
        const val KEY_CUSTOM = "custom_recipes"
    }
}
