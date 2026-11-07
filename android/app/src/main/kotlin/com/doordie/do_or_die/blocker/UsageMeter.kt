package com.doordie.do_or_die.blocker

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

/** Reads app-usage events and measures foreground time of chosen apps. */
object UsageMeter {
    private const val LOOKBACK = 6 * 60 * 60 * 1000L

    /** Usage events between [from] and [to], oldest first, in pure form. */
    fun events(ctx: Context, from: Long, to: Long): List<UsageLogic.Event> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val raw = usm.queryEvents(from, to)
        val out = ArrayList<UsageLogic.Event>()
        val e = UsageEvents.Event()
        while (raw.hasNextEvent()) {
            raw.getNextEvent(e)
            val kind = when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> UsageLogic.Kind.RESUMED
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> UsageLogic.Kind.PAUSED
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.DEVICE_SHUTDOWN,
                UsageEvents.Event.KEYGUARD_SHOWN -> UsageLogic.Kind.SCREEN_OFF
                else -> UsageLogic.Kind.OTHER
            }
            if (kind != UsageLogic.Kind.OTHER) out += UsageLogic.Event(e.timeStamp, kind, e.packageName)
        }
        return out
    }

    /**
     * Milliseconds [packages] were in front between [from] and [to], or -1
     * without usage access. An app already open at [from] counts from [from].
     */
    fun foregroundMillis(ctx: Context, packages: Set<String>, from: Long, to: Long): Long {
        if (to <= from) return 0L
        if (!Permissions.usageAccess(ctx)) return -1L
        return UsageLogic.foregroundMillis(events(ctx, from - LOOKBACK, to), packages, from, to)
    }
}
