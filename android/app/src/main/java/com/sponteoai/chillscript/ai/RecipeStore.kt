package com.sponteoai.chillscript.ai

import android.content.Context
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.util.UUID

@Suppress("UseKtx") // These writes need the boolean result from SharedPreferences.commit().
class RecipeStore(context: Context) {
    private val preferences = context.getSharedPreferences("creator_skills", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }
    private var customRecipes = readCustom()
    private val mutableInstalled = MutableStateFlow(loadInstalled())
    val installed: StateFlow<List<AgentRecipe>> = mutableInstalled.asStateFlow()
    private val mutableFavorites = MutableStateFlow(loadFavorites())
    val favorites: StateFlow<List<AgentRecipe>> = mutableFavorites.asStateFlow()

    val available: List<AgentRecipe>
        get() = BuiltInRecipes.all + customRecipes.getOrElse { emptyList() }
    val customRecipesLoadFailure: Throwable?
        get() = customRecipes.exceptionOrNull()

    init {
        CreatorSkillPreferences.initialize(context)
    }

    fun toggle(recipe: AgentRecipe) {
        val ids = mutableFavorites.value.map { it.id }.toMutableList()
        if (recipe.id in ids) {
            if (ids.size <= 1) return
            ids.remove(recipe.id)
        }
        else if (ids.size < 4) ids.add(recipe.id)
        saveFavoriteIds(ids)
    }

    fun replaceFavorite(old: AgentRecipe, recipe: AgentRecipe) {
        val ids = mutableFavorites.value.map { it.id }.toMutableList()
        val index = ids.indexOf(old.id)
        if (index < 0 || recipe.id in ids) return
        ids[index] = recipe.id
        saveFavoriteIds(ids)
    }

    fun addCustom(name: String, prompt: String, systemIcon: String = "sparkles"): AgentRecipe {
        val recipe = AgentRecipe(
            id = "custom_${UUID.randomUUID()}",
            name = name.trim(),
            description = "Custom skill",
            prompt = prompt.trim(),
            isCustom = true,
            systemIcon = systemIcon.ifBlank { "sparkles" },
        )
        val custom = customRecipes.getOrThrow() + recipe
        saveCustom(custom)
        mutableInstalled.value = loadInstalled()
        return recipe
    }

    fun deleteCustom(recipe: AgentRecipe) {
        if (!recipe.isCustom) return
        val custom = customRecipes.getOrThrow().filterNot { it.id == recipe.id }
        saveCustom(custom)
        saveFavoriteIds(mutableFavorites.value.map { it.id }.filterNot { it == recipe.id })
        mutableInstalled.value = loadInstalled()
    }

    fun clearUserData() {
        check(preferences.edit().clear().commit()) { "Could not clear creator skill preferences" }
        customRecipes = Result.success(emptyList())
        saveFavoriteIds(DEFAULT_FAVORITE_IDS)
        mutableInstalled.value = loadInstalled()
    }

    private fun loadInstalled(): List<AgentRecipe> = available

    private fun loadFavorites(): List<AgentRecipe> {
        val ids = preferences.getString(KEY_FAVORITES, null)?.let { encoded ->
            runCatching { json.decodeFromString<List<String>>(encoded) }.getOrNull()
        } ?: DEFAULT_FAVORITE_IDS
        val all = available.associateBy { it.id }
        return ids.distinct().mapNotNull(all::get).take(4).ifEmpty {
            DEFAULT_FAVORITE_IDS.take(1).mapNotNull(all::get)
        }
    }

    private fun saveFavoriteIds(ids: List<String>) {
        val valid = available.mapTo(mutableSetOf()) { it.id }
        val normalized = ids.distinct().filter { it in valid }.take(4).ifEmpty {
            DEFAULT_FAVORITE_IDS.take(1).filter { it in valid }
        }
        val encoded = json.encodeToString(ListSerializer(String.serializer()), normalized)
        check(preferences.edit().putString(KEY_FAVORITES, encoded).commit()) {
            "Could not save favorite creator skills"
        }
        mutableFavorites.value = loadFavorites()
    }

    private fun readCustom(): Result<List<AgentRecipe>> = runCatching {
        json.decodeFromString(ListSerializer(AgentRecipe.serializer()), preferences.getString(KEY_CUSTOM, "[]") ?: "[]")
    }

    private fun saveCustom(recipes: List<AgentRecipe>) {
        val encoded = json.encodeToString(ListSerializer(AgentRecipe.serializer()), recipes)
        check(preferences.edit().putString(KEY_CUSTOM, encoded).commit()) {
            "Could not save custom creator skills"
        }
        customRecipes = Result.success(recipes)
    }

    private companion object {
        const val KEY_FAVORITES = "favorite_ids"
        val DEFAULT_FAVORITE_IDS = listOf("rewrite", "hook_generator", "caption_pack", "repurpose_pack")
        const val KEY_CUSTOM = "custom_recipes"
    }
}
