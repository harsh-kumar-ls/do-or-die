package com.doordie.do_or_die.blocker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.doordie.do_or_die.TrustedTime
import java.util.Calendar

/**
 * Wakes the watcher exactly when it is needed, so it doesn't run all day:
 * just after midnight (a verdict becomes due) and just before a scheduled
 * lock. Exact alarms are exempt from Android's background limits on
 * starting a foreground service. Without the exact-alarm permission the
 * watcher simply never stops (see [UsageLogic.watcherNeeded]).
 */
object WakeScheduler {
    private const val MIDNIGHT = 1
    private const val LOCK = 2
    private const val LEAD_MS = 60_000L

    fun canScheduleExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return false
        return am.canScheduleExactAlarms()
    }

    private fun intent(ctx: Context, code: Int): PendingIntent = PendingIntent.getBroadcast(
        ctx,
        code,
        Intent(ctx, WakeReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Schedules the next wake-ups. Returns false if exact alarms aren't allowed. */
    fun schedule(ctx: Context): Boolean {
        if (!canScheduleExact(ctx)) return false
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return false
        val now = TrustedTime.nowMillis(ctx)
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 10)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        return try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, midnight, intent(ctx, MIDNIGHT))
            val start = BlockerState.lockStartsAt(ctx)
            if (start - LEAD_MS > now) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start - LEAD_MS, intent(ctx, LOCK))
            } else {
                am.cancel(intent(ctx, LOCK))
            }
            true
        } catch (e: SecurityException) {
            false
        }
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        am.cancel(intent(ctx, MIDNIGHT))
        am.cancel(intent(ctx, LOCK))
    }
}

/** An exact alarm fired: start the watcher if it is needed now. */
class WakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WatcherService.sync(context)
    }
}
