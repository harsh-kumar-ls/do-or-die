package com.doordie.do_or_die.blocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.doordie.do_or_die.MainActivity
import com.doordie.do_or_die.R

/**
 * Shown when Android refused to start the watcher from the background: the
 * lock can't be enforced until the app is opened (a start from the
 * foreground is always allowed). Tapping it opens Do or Die.
 */
object StartFailureNotice {
    private const val CHANNEL = "lock_alerts"
    private const val ID = 4472

    fun show(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Lock alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "When a lock you set up could not start on its own."
            },
        )
        val open = PendingIntent.getActivity(
            ctx,
            1,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notice: Notification = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("[ SYSTEM ] The lock could not start")
            .setContentText("Android stopped the watcher. Open Do or Die to arm it.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(ID, notice)
        } catch (e: SecurityException) {
            // Notifications are off; the failure is still recorded.
        }
    }

    fun cancel(ctx: Context) {
        ctx.getSystemService(NotificationManager::class.java)?.cancel(ID)
    }
}
