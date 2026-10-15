package com.flourish.app.detect

import android.content.Context
import org.json.JSONObject

/** What the person allowed, mirrored from Flutter by `configure`. */
object DetectionConfig {
    private const val PREFS = "flourish_detection"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(context: Context) = prefs(context).getBoolean("enabled", false)
    fun notify(context: Context) = prefs(context).getBoolean("notify", true)
    fun packages(context: Context): Set<String> =
        prefs(context).getStringSet("packages", emptySet()) ?: emptySet()

    fun save(context: Context, enabled: Boolean, packages: List<String>, notify: Boolean) {
        prefs(context).edit()
            .putBoolean("enabled", enabled)
            .putStringSet("packages", packages.toSet())
            .putBoolean("notify", notify)
            .apply()
    }

    /**
     * Counts apps outside the allow-list that posted money-like
     * notifications, so the person can add their bank app. Only the package,
     * its label and a count are kept, never the text.
     */
    fun recordCandidate(context: Context, packageName: String, label: String) {
        val p = prefs(context)
        val all = JSONObject(p.getString("candidates", "{}") ?: "{}")
        val entry = all.optJSONObject(packageName) ?: JSONObject().put("count", 0)
        entry.put("label", label).put("count", entry.optInt("count") + 1)
        all.put(packageName, entry)
        p.edit().putString("candidates", all.toString()).apply()
    }

    fun candidates(context: Context): List<Map<String, Any>> {
        val all = JSONObject(prefs(context).getString("candidates", "{}") ?: "{}")
        return all.keys().asSequence().map { key ->
            val e = all.getJSONObject(key)
            mapOf("packageName" to key, "label" to e.optString("label", key), "count" to e.optInt("count"))
        }.sortedByDescending { it["count"] as Int }.toList()
    }
}
