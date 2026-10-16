package com.flourish.app.detect

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Captured messages waiting for the Flutter side, one JSON object per line
 * in the app's private files. Survives process death; Flutter reads with
 * [peek] and removes with [ack], so delivery is at-least-once.
 */
object DetectionQueue {
    private const val MAX_LINES = 1000
    private val lock = Any()

    private fun file(context: Context): File =
        File(context.filesDir, "detection/queue.jsonl").also { it.parentFile?.mkdirs() }

    fun append(
        context: Context,
        text: String,
        sender: String?,
        packageName: String?,
        receivedAtIso: String,
        source: String,
    ) {
        synchronized(lock) {
            val entry = JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("text", text)
                .put("sender", sender ?: JSONObject.NULL)
                .put("packageName", packageName ?: JSONObject.NULL)
                .put("receivedAt", receivedAtIso)
                .put("source", source)
            val target = file(context)
            target.appendText(entry.toString().replace("\n", " ") + "\n")
            val lines = target.readLines()
            if (lines.size > MAX_LINES) rewrite(target, lines.takeLast(MAX_LINES))
        }
    }

    fun peek(context: Context, limit: Int = 200): List<Map<String, Any?>> {
        synchronized(lock) {
            val target = file(context)
            if (!target.exists()) return emptyList()
            return target.readLines().filter { it.isNotBlank() }.take(limit).mapNotNull { line ->
                try {
                    val o = JSONObject(line)
                    mapOf(
                        "id" to o.getString("id"),
                        "text" to o.optString("text"),
                        "sender" to (if (o.isNull("sender")) null else o.optString("sender")),
                        "packageName" to
                            (if (o.isNull("packageName")) null else o.optString("packageName")),
                        "receivedAt" to o.optString("receivedAt"),
                        "source" to o.optString("source", "android_notification"),
                    )
                } catch (_: Exception) {
                    null
                }
            }
        }
    }

    fun ack(context: Context, ids: Collection<String>) {
        synchronized(lock) {
            val target = file(context)
            if (!target.exists() || ids.isEmpty()) return
            val keep = target.readLines().filter { line ->
                if (line.isBlank()) return@filter false
                val id = try {
                    JSONObject(line).optString("id")
                } catch (_: Exception) {
                    ""
                }
                id.isNotEmpty() && id !in ids
            }
            rewrite(target, keep)
        }
    }

    /** Writes through a temporary file so a crash never leaves half a queue. */
    private fun rewrite(target: File, lines: List<String>) {
        val temp = File(target.parentFile, "queue.jsonl.tmp")
        temp.writeText(if (lines.isEmpty()) "" else lines.joinToString("\n", postfix = "\n"))
        if (!temp.renameTo(target)) {
            target.writeText(temp.readText())
            temp.delete()
        }
    }
}
