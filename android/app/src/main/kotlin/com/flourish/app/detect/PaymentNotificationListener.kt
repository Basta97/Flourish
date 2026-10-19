package com.flourish.app.detect

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import java.time.Instant

/**
 * Reads notifications from the messaging app (bank SMS) and from the bank
 * and wallet apps the person picked, and queues those that look like a
 * payment. Everything else is dropped on the spot; nothing leaves the
 * device.
 */
class PaymentNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (e: Exception) {
            // A malformed notification must never crash the listener. Only
            // the error type is logged, never the notification's text.
            android.util.Log.w("FlourishDetect", "Skipped a notification: ${e.javaClass.name}")
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        val context: Context = applicationContext
        if (!DetectionConfig.enabled(context)) return
        if (sbn.packageName == packageName || sbn.isOngoing) return
        val notification = sbn.notification ?: return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val allowed = sbn.packageName in DetectionConfig.packages(context)
        val messages = extract(notification)
        for ((text, sender, time) in messages) {
            if (!PreFilter.looksLikePayment(text)) continue
            if (!allowed) {
                DetectionConfig.recordCandidate(context, sbn.packageName, label(sbn.packageName))
                return
            }
            // Updates of the same SMS thread re-post its last message with the
            // same timestamp; two real alerts with the same words do not.
            val key = sbn.packageName + "|" + text + (if (time > 0) "|$time" else "")
            if (!RecentAlerts.firstSeen(context, key)) continue
            DetectionQueue.append(
                context,
                text = text,
                sender = sender,
                packageName = sbn.packageName,
                receivedAtIso = Instant.ofEpochMilli(if (time > 0) time else sbn.postTime).toString(),
                source = "android_notification",
            )
            DetectionChannel.onQueued(context)
        }
    }

    /** Each message with its sender and time; falls back to title + text. */
    private fun extract(notification: Notification): List<Triple<String, String?, Long>> {
        val style = NotificationCompat.MessagingStyle
            .extractMessagingStyleFromNotification(notification)
        if (style != null && style.messages.isNotEmpty()) {
            val conversation = style.conversationTitle?.toString()
            // Only the newest message: older ones were seen in earlier posts.
            val last = style.messages.last()
            val text = last.text?.toString() ?: return emptyList()
            val sender = last.person?.name?.toString() ?: conversation
            return listOf(Triple(text, sender, last.timestamp))
        }
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                ?.joinToString("\n") { it.toString() }
            ?: return emptyList()
        return listOf(Triple(text, title, 0L))
    }

    private fun label(pkg: String): String = try {
        val pm = applicationContext.packageManager
        val info = if (Build.VERSION.SDK_INT >= 33) {
            pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(pkg, 0)
        }
        pm.getApplicationLabel(info).toString()
    } catch (_: Exception) {
        pkg
    }

    /**
     * Android binds the listener a moment after access is granted, after an
     * app update and after a reboot. Alerts still on screen from that gap are
     * read now; the 24-hour guard keeps anything seen before from doubling.
     */
    override fun onListenerConnected() {
        super.onListenerConnected()
        try {
            activeNotifications?.forEach { onNotificationPosted(it) }
        } catch (e: Exception) {
            android.util.Log.w("FlourishDetect", "Could not read current notifications: ${e.javaClass.name}")
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        requestRebind(ComponentName(this, PaymentNotificationListener::class.java))
    }
}
