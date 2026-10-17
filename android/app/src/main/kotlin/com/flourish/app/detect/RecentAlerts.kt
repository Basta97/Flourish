package com.flourish.app.detect

import android.content.Context
import org.json.JSONObject
import java.security.MessageDigest

/**
 * Alerts queued in the last 24 hours, kept as hashes in private preferences
 * so a re-posted or updated notification queues once even after the
 * listener's process was restarted. The text itself is never stored here.
 */
object RecentAlerts {
    private const val PREFS = "flourish_detection_recent"
    private const val KEY = "seen"
    private const val WINDOW_MS = 24 * 60 * 60 * 1000L
    private const val MAX_ENTRIES = 500
    private val lock = Any()

    /** True the first time [key] is offered within 24 hours, and records it. */
    fun firstSeen(context: Context, key: String, now: Long = System.currentTimeMillis()): Boolean {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val seen = try {
                JSONObject(prefs.getString(KEY, "{}") ?: "{}")
            } catch (_: Exception) {
                JSONObject()
            }
            val kept = seen.keys().asSequence()
                .map { it to seen.optLong(it) }
                .filter { now - it.second in 0..WINDOW_MS }
                .sortedByDescending { it.second }
                .take(MAX_ENTRIES - 1)
                .toList()
            val hash = sha256(key)
            if (kept.any { it.first == hash }) return false
            val next = JSONObject()
            kept.forEach { next.put(it.first, it.second) }
            next.put(hash, now)
            prefs.edit().putString(KEY, next.toString()).apply()
            return true
        }
    }

    private fun sha256(text: String): String =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray())
            .joinToString("") { "%02x".format(it) }
}
