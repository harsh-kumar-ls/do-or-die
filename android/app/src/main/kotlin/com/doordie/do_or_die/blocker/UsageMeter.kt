package com.doordie.do_or_die.blocker

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

/** Measures foreground time of chosen apps, for screen-time caps. */
object UsageMeter {
    /**
     * Milliseconds [packages] were in front between [from] and [to], or -1
     * without usage access. Built from resume/pause events so an app already
     * open at [from] is counted from [from], and one still open at [to] up to [to].
     */
    fun foregroundMillis(ctx: Context, packages: Set<String>, from: Long, to: Long): Long {
        if (!Permissions.usageAccess(ctx) || to <= from) return if (to <= from) 0L else -1L
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        // Look back a little so an app opened just before [from] is seen.
        val events = usm.queryEvents(from - LOOKBACK, to)
        val openSince = HashMap<String, Long>()
        var total = 0L
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            if (pkg !in packages) continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> openSince.putIfAbsent(pkg, e.timeStamp)
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val start = openSince.remove(pkg) ?: continue
                    total += overlap(start, e.timeStamp, from, to)
                }
            }
        }
        for (start in openSince.values) total += overlap(start, to, from, to)
        return total
    }

    private fun overlap(s: Long, e: Long, from: Long, to: Long): Long =
        maxOf(0L, minOf(e, to) - maxOf(s, from))

    private const val LOOKBACK = 6 * 60 * 60 * 1000L
}
