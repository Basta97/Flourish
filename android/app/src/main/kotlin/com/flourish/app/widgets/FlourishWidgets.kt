package com.flourish.app.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.flourish.app.MainActivity
import com.flourish.app.R
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date
import java.util.Locale

object WidgetStore {
    const val ACTION_EXTRA = "flourish.widget.action"
    private const val STORE = "flourish_widgets"
    fun publish(context: Context, json: String) {
        // Replacing the complete snapshot also removes previously public totals.
        JSONObject(json) // Reject malformed writes.
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit().putString("snapshot", json).commit()
        refresh(context)
    }
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in listOf(MonthlySummaryWidget::class.java, QuickAddWidget::class.java)) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            for (id in ids) render(context, manager, id, provider == QuickAddWidget::class.java)
        }
        val data = snapshot(context)
        val end = data.optLong("periodEnd")
        if (end > System.currentTimeMillis()) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MonthlySummaryWidget::class.java).setAction("com.flourish.WIDGET_BOUNDARY")
            val pending = PendingIntent.getBroadcast(context, 901, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.set(AlarmManager.RTC, end, pending)
        }
    }
    private fun snapshot(context: Context) = try {
        JSONObject(context.getSharedPreferences(STORE, Context.MODE_PRIVATE).getString("snapshot", "{}") ?: "{}")
    } catch (_: Exception) { JSONObject() }
    private fun open(context: Context, action: String, request: Int): PendingIntent = PendingIntent.getActivity(
        context, request, Intent(context, MainActivity::class.java)
            .setAction("com.flourish.widget.$action").putExtra(ACTION_EXTRA, action)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun render(context: Context, manager: AppWidgetManager, id: Int, quick: Boolean) {
        val data = snapshot(context)
        val views = RemoteViews(context.packageName, if (quick) R.layout.flourish_quick_widget else R.layout.flourish_widget)
        val stale = data.optLong("periodEnd") <= System.currentTimeMillis()
        val hidden = data.optBoolean("hidden", true)
        val locale = Locale.forLanguageTag(data.optString("locale", Locale.getDefault().language))
        views.setInt(R.id.widget_root, "setLayoutDirection", if (locale.language == "ar") View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        views.setTextViewText(R.id.widget_title, if (quick) data.optString("quickTitle", context.getString(R.string.widget_quick)) else data.optString("title", context.getString(R.string.widget_summary)))
        views.setViewVisibility(R.id.widget_totals, if (quick) View.GONE else View.VISIBLE)
        val currency = data.optString("currency", "EGP")
        val income = if (hidden) "••••" else data.optString("income", "—")
        val spending = if (hidden) "••••" else data.optString("spending", "—")
        views.setTextViewText(R.id.widget_totals, if (stale) data.optString("refreshLabel", context.getString(R.string.widget_refresh))
            else if (data.optBoolean("empty")) data.optString("emptyLabel", context.getString(R.string.widget_refresh))
            else "${data.optString("incomeLabel", context.getString(R.string.widget_income))}: $income $currency\n${data.optString("spendingLabel", context.getString(R.string.widget_spending))}: $spending $currency")
        val updated = data.optLong("updatedAt")
        val date = if (updated > 0) DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT, locale).format(Date(updated)) else ""
        val warning = if (data.optInt("missingRates") > 0) " · ${data.optString("refreshLabel", context.getString(R.string.widget_refresh))}" else ""
        views.setTextViewText(R.id.widget_updated, if (date.isEmpty()) context.getString(R.string.widget_refresh) else "${data.optString("updatedLabel", context.getString(R.string.widget_updated))} $date$warning")
        views.setTextViewText(R.id.widget_add, data.optString("addLabel", context.getString(R.string.widget_add)))
        views.setTextViewText(R.id.widget_template, data.optString("templateLabel", context.getString(R.string.widget_template)))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, "home", 100))
        views.setOnClickPendingIntent(R.id.widget_add, open(context, "add", 101))
        views.setOnClickPendingIntent(R.id.widget_template, open(context, "template", 102))
        manager.updateAppWidget(id, views)
    }
}
class MonthlySummaryWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { WidgetStore.refresh(context) }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf("com.flourish.WIDGET_BOUNDARY", Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED)) WidgetStore.refresh(context)
    }
}
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { WidgetStore.refresh(context) }
}
