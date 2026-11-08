package com.doordie.do_or_die.blocker

/**
 * Pure logic behind the watcher and the screen-time meter, kept free of
 * Android classes so it runs in plain JVM unit tests.
 */
object UsageLogic {
    /** What an app-usage event means for these rules. */
    enum class Kind { RESUMED, PAUSED, SCREEN_OFF, OTHER }

    data class Event(val time: Long, val kind: Kind, val pkg: String?)

    /**
     * The app in front after [events] (oldest first): the last one resumed,
     * or null if the screen went off or locked after it.
     */
    fun foreground(events: List<Event>): String? {
        var pkg: String? = null
        for (e in events) {
            when (e.kind) {
                Kind.RESUMED -> pkg = e.pkg
                Kind.SCREEN_OFF -> pkg = null
                else -> {}
            }
        }
        return pkg
    }

    /**
     * Milliseconds [packages] were in front between [from] and [to]. Only one
     * app is in front at a time: any other app resuming, or the screen going
     * off, ends every open session, so a missing pause event (the battery
     * died with the app open) can't count hours that never happened.
     */
    fun foregroundMillis(events: List<Event>, packages: Set<String>, from: Long, to: Long): Long {
        if (to <= from) return 0L
        val openSince = HashMap<String, Long>()
        var total = 0L
        fun overlap(s: Long, e: Long) = maxOf(0L, minOf(e, to) - maxOf(s, from))
        fun closeAll(at: Long) {
            for (start in openSince.values) total += overlap(start, at)
            openSince.clear()
        }
        for (e in events) {
            when (e.kind) {
                Kind.RESUMED -> {
                    if (e.pkg != null && e.pkg in packages) {
                        val mine = openSince.remove(e.pkg)
                        closeAll(e.time)
                        openSince[e.pkg] = mine ?: e.time
                    } else {
                        closeAll(e.time)
                    }
                }
                Kind.PAUSED -> {
                    if (e.pkg != null && e.pkg in packages) {
                        val start = openSince.remove(e.pkg) ?: continue
                        total += overlap(start, e.time)
                    }
                }
                Kind.SCREEN_OFF -> closeAll(e.time)
                Kind.OTHER -> {}
            }
        }
        for (start in openSince.values) total += overlap(start, to)
        return total
    }

    /** yyyy-MM-dd strings sort in date order; malformed input never matches. */
    fun dayBefore(due: String?, today: String): Boolean {
        if (due == null || !ISO_DAY.matches(due) || !ISO_DAY.matches(today)) return false
        return due < today
    }

    /**
     * A verdict is due when the first unjudged day is before today, unless
     * the app last saw that day fully cleared ([questDoneFor]): then its
     * verdict is already known and nothing needs to be redirected.
     */
    fun verdictDue(due: String?, today: String, questDoneFor: String?): Boolean {
        if (!dayBefore(due, today)) return false
        // The waiver covers only yesterday: an older unjudged day was never
        // seen to the end, so its verdict is still unknown.
        val yesterday = java.time.LocalDate.parse(today).minusDays(1).toString()
        return !(due == questDoneFor && due == yesterday)
    }

    private val ISO_DAY = Regex("""\d{4}-\d{2}-\d{2}""")

    /**
     * Whether the watcher must run now: a lock or block is on, a verdict is
     * due, a lock starts within [soonMs], or exact alarms can't wake it in
     * time (then it never stops).
     */
    fun watcherNeeded(
        locked: Boolean,
        needsJudgement: Boolean,
        now: Long,
        lockStartsAt: Long,
        lockEndsAt: Long,
        exactAlarms: Boolean,
        soonMs: Long = 2 * 60_000L,
    ): Boolean {
        if (!exactAlarms) return true
        if (locked || needsJudgement) return true
        return lockEndsAt > now && lockStartsAt - now <= soonMs
    }
}
