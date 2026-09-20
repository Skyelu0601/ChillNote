package com.sponteoai.chillscript.chillo

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.UUID

@Serializable data class ChilloSource(val number: Int, val noteId: String, val availability: String, val title: String, val excerpt: String, val platform: String? = null)
@Serializable data class ChilloTurn(val id: String, val request: String, val answer: String, val status: String, val errorCode: String? = null, val sources: List<ChilloSource> = emptyList(), val sourcesChanged: Boolean = false, val draftNoteId: String? = null) {
    val active get() = status == "queued" || status == "running"
}
@Serializable data class ChilloConversation(val id: String, val title: String)
@Serializable data class ChilloDetail(val id: String, val turns: List<ChilloTurn>, val pinnedIds: List<String>, val excludedIds: List<String>, val olderCursor: String? = null)
@Serializable data class ChilloHistory(val conversations: List<ChilloConversation>, val nextCursor: String? = null)
@Serializable data class ChilloLibrary(val total: Int, val available: Int, val indexed: Int, val pending: Int, val consentVersion: Int)
data class ChilloState(
    val conversationId: String? = null, val turns: List<ChilloTurn> = emptyList(), val history: List<ChilloConversation> = emptyList(),
    val library: ChilloLibrary? = null, val input: String = "", val busy: Boolean = false, val loading: Boolean = false,
    val error: String? = null, val olderCursor: String? = null, val historyCursor: String? = null,
) {
    val generating get() = turns.any { it.active }
    val needsConsent get() = library?.consentVersion != 1
}

interface ChilloDataSource {
    val json: Json
    suspend fun request(path: String, method: String = "GET", body: JsonObject? = null): JsonObject
}

class ChilloApi(private val tokenProvider: suspend () -> String?, private val baseUrl: String = "https://api.chillnoteai.com") : ChilloDataSource {
    class Failure(val code: String) : Exception(code)
    override val json = Json { ignoreUnknownKeys = true }
    override suspend fun request(path: String, method: String, body: JsonObject?): JsonObject {
        val token = tokenProvider() ?: throw Failure("UNAUTHORIZED")
        return withContext(Dispatchers.IO) {
            val connection = URL("$baseUrl/chillo$path").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method; connection.connectTimeout = 15000; connection.readTimeout = 30000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Authorization", "Bearer $token")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                }
                val success = connection.responseCode in 200..299
                val stream = if (success) connection.inputStream else connection.errorStream
                val result = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val parsed = runCatching { json.parseToJsonElement(result).jsonObject }.getOrNull()
                if (!success) throw Failure(parsed?.get("error")?.jsonPrimitive?.contentOrNull ?: "REQUEST_FAILED")
                parsed ?: throw Failure("REQUEST_FAILED")
            } finally { connection.disconnect() }
        }
    }
}

class ChilloController(private val api: ChilloDataSource) {
    private val mutable = MutableStateFlow(ChilloState())
    val state = mutable.asStateFlow()
    private var pending: Pair<String, String>? = null
    private var pinnedIds = emptyList<String>()
    private var excludedIds = emptyList<String>()
    fun input(text: String) { mutable.value = mutable.value.copy(input = text) }
    fun newConversation() {
        if (mutable.value.busy) return
        mutable.value = mutable.value.copy(conversationId = null, turns = emptyList(), input = "", error = null, olderCursor = null)
        pinnedIds = emptyList(); excludedIds = emptyList(); pending = null
    }
    private suspend fun attempt(block: suspend () -> Unit) {
        try { block(); mutable.value = mutable.value.copy(error = null) }
        catch (cancelled: CancellationException) { throw cancelled }
        catch (error: Exception) { mutable.value = mutable.value.copy(error = (error as? ChilloApi.Failure)?.code ?: "REQUEST_FAILED") }
    }
    suspend fun load() {
        mutable.value = mutable.value.copy(loading = true)
        try { attempt { mutable.value = mutable.value.copy(library = api.json.decodeFromJsonElement(api.request("/library"))); history() } }
        finally { mutable.value = mutable.value.copy(loading = false) }
    }
    suspend fun consent(accept: Boolean) = attempt {
        api.request("/consent", "PUT", buildJsonObject { put("version", if (accept) 1 else 0) })
        mutable.value = mutable.value.copy(library = api.json.decodeFromJsonElement(api.request("/library")))
        refresh()
    }
    private suspend fun history(more: Boolean = false) {
        val suffix = if (more) mutable.value.historyCursor?.let { "?cursor=$it" }.orEmpty() else ""
        val result = api.json.decodeFromJsonElement<ChilloHistory>(api.request("/conversations$suffix"))
        mutable.value = mutable.value.copy(history = if (more) (mutable.value.history + result.conversations).distinctBy { it.id } else result.conversations, historyCursor = result.nextCursor)
    }
    suspend fun moreHistory() = attempt { history(true) }
    suspend fun open(id: String) = attempt {
        if (mutable.value.busy) return@attempt
        val detail = api.json.decodeFromJsonElement<ChilloDetail>(api.request("/conversations/$id"))
        mutable.value = mutable.value.copy(conversationId = id, turns = detail.turns, input = "", olderCursor = detail.olderCursor)
        pinnedIds = detail.pinnedIds; excludedIds = detail.excludedIds; pending = null
    }
    suspend fun send() {
        val current = mutable.value
        val message = current.input.trim()
        if (current.busy || current.generating || current.needsConsent || message.isEmpty() || message.length > 16000) return
        mutable.value = current.copy(busy = true)
        try { attempt {
            val id = mutable.value.conversationId ?: UUID.randomUUID().toString().also { mutable.value = mutable.value.copy(conversationId = it) }
            api.request("/conversations", "POST", buildJsonObject { put("id", id) })
            if (pending?.second != message) pending = UUID.randomUUID().toString() to message
            val turn = api.json.decodeFromJsonElement<ChilloTurn>(api.request("/conversations/$id/turns", "POST", buildJsonObject {
                put("id", pending!!.first); put("message", message); put("locale", Locale.getDefault().toLanguageTag())
            }))
            mutable.value = mutable.value.copy(input = "", turns = (mutable.value.turns + turn).distinctBy { it.id })
            pending = null; history()
        } } finally { mutable.value = mutable.value.copy(busy = false) }
    }
    private suspend fun refresh() {
        val id = mutable.value.conversationId ?: return
        val detail = api.json.decodeFromJsonElement<ChilloDetail>(api.request("/conversations/$id"))
        if (mutable.value.conversationId != id) return
        val ids = detail.turns.map { it.id }.toSet()
        mutable.value = mutable.value.copy(turns = mutable.value.turns.filterNot { it.id in ids } + detail.turns,
            olderCursor = if (mutable.value.turns.size <= 40) detail.olderCursor else mutable.value.olderCursor)
    }
    suspend fun reload() = attempt { refresh() }
    suspend fun poll() { while (true) { delay(2000); if (mutable.value.generating && !mutable.value.busy) reload() } }
    suspend fun older() = attempt {
        val id = mutable.value.conversationId ?: return@attempt
        val cursor = mutable.value.olderCursor ?: return@attempt
        val detail = api.json.decodeFromJsonElement<ChilloDetail>(api.request("/conversations/$id?cursor=$cursor"))
        if (mutable.value.conversationId == id) mutable.value = mutable.value.copy(turns = (detail.turns + mutable.value.turns).distinctBy { it.id }, olderCursor = detail.olderCursor)
    }
    suspend fun delete(id: String) = attempt {
        api.request("/conversations/$id", "DELETE")
        mutable.value = mutable.value.copy(history = mutable.value.history.filterNot { it.id == id })
        if (mutable.value.conversationId == id) newConversation()
    }
    suspend fun action(action: String, turn: ChilloTurn): String? {
        val id = mutable.value.conversationId ?: return null
        if (mutable.value.busy) return null
        mutable.value = mutable.value.copy(busy = true)
        var noteId: String? = null
        try { attempt {
            val result = api.request("/conversations/$id/turns/${turn.id}/$action", "POST")
            noteId = result["noteId"]?.jsonPrimitive?.contentOrNull
            refresh()
        } } finally { mutable.value = mutable.value.copy(busy = false) }
        return noteId
    }
    suspend fun exclude(source: ChilloSource) = attempt {
        val id = mutable.value.conversationId ?: return@attempt
        val updated = (excludedIds + source.noteId).distinct()
        api.request("/conversations/$id", "PATCH", buildJsonObject {
            put("pinnedIds", JsonArray(pinnedIds.filterNot { it == source.noteId }.map(::JsonPrimitive)))
            put("excludedIds", JsonArray(updated.map(::JsonPrimitive)))
        })
        excludedIds = updated
    }
}
