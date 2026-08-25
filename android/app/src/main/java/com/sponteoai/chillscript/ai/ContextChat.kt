package com.sponteoai.chillscript.ai

import com.sponteoai.chillscript.data.local.NoteEntity
import java.util.UUID

enum class ChatRole { USER, ASSISTANT }

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: ChatRole,
    val content: String,
    val createdAt: Long = System.currentTimeMillis(),
)

object ContextChatPrompt {
    fun build(
        notes: List<NoteEntity>,
        history: List<ChatMessage>,
        userMessage: String,
        installedRecipes: List<AgentRecipe>,
    ): Pair<String, String> {
        val context = notes.mapIndexed { index, note ->
            "Note [${index + 1}]\nCreated: ${note.createdAt}\nContent: ${note.content}"
        }.joinToString("\n\n")
        val recent = history.takeLast(8).joinToString("\n\n") { message ->
            "${if (message.role == ChatRole.USER) "User" else "Assistant"}: ${sanitize(message.content)}"
        }.ifBlank { "No recent turns." }
        val command = parseRecipeCommand(userMessage, installedRecipes)
        val prompt = if (command == null) {
            """
                You are an AI assistant with access to user notes as long-term memory.

                Rules:
                1) Prioritize facts from User Notes whenever possible.
                2) Cite a directly used note with its exact number, such as [1] or [1][3].
                3) Do not cite general knowledge.
                4) If a key fact is missing, ask one short follow-up question instead of guessing.
                5) Never invent a note number.

                Recent Conversation Turns:
                $recent

                User Notes:
                $context

                Current User Question:
                $userMessage
            """.trimIndent()
        } else {
            val (recipe, extra) = command
            """
                Apply a saved creator skill inside chat.

                Skill: ${recipe.name} (${recipe.id})
                Skill Instruction: ${recipe.prompt}
                Extra User Instruction: ${extra.ifBlank { "No extra instruction." }}

                Recent Conversation Turns:
                $recent

                User Notes:
                $context

                Return only the final answer. Do not repeat the slash command. Cite directly used notes only with valid numbers like [1].
            """.trimIndent()
        }
        val system = """
            You are a clear, direct, and accurate assistant working with the user's selected notes.
            Always answer in the language of the user's latest question, even when notes use another language.
            Use citations only for statements directly supported by a selected note. Never invent citations.
            ${if (command == null) "" else "Follow the selected creator skill faithfully and return only the answer body."}
        """.trimIndent()
        return prompt to system
    }

    fun parseRecipeCommand(input: String, recipes: List<AgentRecipe>): Pair<AgentRecipe, String>? {
        val trimmed = input.trim()
        if (!trimmed.startsWith('/')) return null
        val parts = trimmed.drop(1).split(Regex("\\s+"), limit = 2)
        val recipe = recipes.firstOrNull { it.id == parts.firstOrNull() } ?: return null
        return recipe to parts.getOrElse(1) { "" }
    }

    fun sanitize(text: String): String = text.replace("\r\n", "\n")
        .lineSequence()
        .dropWhile { it.trim().startsWith("source:", ignoreCase = true) }
        .joinToString("\n")
        .trim()
}
