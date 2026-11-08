package com.doordie.do_or_die.blocker

import com.doordie.do_or_die.blocker.UsageLogic.Event
import com.doordie.do_or_die.blocker.UsageLogic.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageLogicTest {
    private val insta = "com.instagram.android"
    private val yt = "com.google.android.youtube"
    private val home = "com.android.launcher"

    @Test
    fun `an app opened before the lock is the one in front`() {
        // Opened 40 minutes ago and still open: the first busy check must see it.
        val events = listOf(Event(1_000, Kind.RESUMED, home), Event(2_000, Kind.PAUSED, home), Event(3_000, Kind.RESUMED, insta))
        assertEquals(insta, UsageLogic.foreground(events))
    }

    @Test
    fun `screen off or keyguard after it means nothing is in front`() {
        val events = listOf(Event(1_000, Kind.RESUMED, insta), Event(2_000, Kind.SCREEN_OFF, null))
        assertNull(UsageLogic.foreground(events))
    }

    @Test
    fun `measured time counts only the chosen apps, clipped to the window`() {
        val events = listOf(
            Event(0, Kind.RESUMED, insta),
            Event(10_000, Kind.PAUSED, insta),
            Event(20_000, Kind.RESUMED, home),
            Event(30_000, Kind.RESUMED, yt),
            Event(50_000, Kind.PAUSED, yt),
        )
        assertEquals(5_000L + 20_000L, UsageLogic.foregroundMillis(events, setOf(insta, yt), 5_000, 100_000))
        assertEquals(5_000L, UsageLogic.foregroundMillis(events, setOf(insta), 5_000, 100_000))
    }

    @Test
    fun `a missing pause never counts hours that did not happen`() {
        val events = listOf(Event(0, Kind.RESUMED, insta), Event(10_000, Kind.SCREEN_OFF, null))
        assertEquals(10_000L, UsageLogic.foregroundMillis(events, setOf(insta), 0, 3_600_000))
    }

    @Test
    fun `an app still open at the end counts up to the end`() {
        val events = listOf(Event(0, Kind.RESUMED, insta))
        assertEquals(60_000L, UsageLogic.foregroundMillis(events, setOf(insta), 0, 60_000))
    }

    @Test
    fun `verdict due only when the due day is before today`() {
        assertTrue(UsageLogic.dayBefore("2026-11-06", "2026-11-07"))
        assertFalse(UsageLogic.dayBefore("2026-11-07", "2026-11-07"))
        assertFalse(UsageLogic.dayBefore(null, "2026-11-07"))
        assertFalse(UsageLogic.dayBefore("garbage", "2026-11-07"))
    }

    @Test
    fun `no game, no lock, no verdict due - the watcher may sleep`() {
        assertFalse(UsageLogic.watcherNeeded(false, false, now = 1_000, lockStartsAt = 0, lockEndsAt = 0, exactAlarms = true))
    }

    @Test
    fun `without exact alarms the watcher never stops`() {
        assertTrue(UsageLogic.watcherNeeded(false, false, now = 1_000, lockStartsAt = 0, lockEndsAt = 0, exactAlarms = false))
    }

    @Test
    fun `needed while locked, while a verdict is due, and just before a lock`() {
        assertTrue(UsageLogic.watcherNeeded(true, false, 1_000, 0, 0, true))
        assertTrue(UsageLogic.watcherNeeded(false, true, 1_000, 0, 0, true))
        val now = 10_000_000L
        assertTrue(UsageLogic.watcherNeeded(false, false, now, now + 60_000, now + 4 * 3_600_000, true))
        assertFalse(UsageLogic.watcherNeeded(false, false, now, now + 3_600_000, now + 5 * 3_600_000, true))
    }

    @Test
    fun `needed during a release inside the lock window`() {
        val now = 10_000_000L
        assertTrue(UsageLogic.watcherNeeded(false, false, now, now - 60_000, now + 3_600_000, true))
    }

    @Test
    fun `a day already seen cleared needs no redirect after midnight`() {
        assertFalse(UsageLogic.verdictDue("2026-11-06", "2026-11-07", questDoneFor = "2026-11-06"))
        assertTrue(UsageLogic.verdictDue("2026-11-06", "2026-11-07", questDoneFor = "2026-11-05"))
        assertTrue(UsageLogic.verdictDue("2026-11-06", "2026-11-07", questDoneFor = null))
        assertFalse(UsageLogic.verdictDue("2026-11-07", "2026-11-07", questDoneFor = null))
        // Two days unjudged: the older one was never seen cleared.
        assertTrue(UsageLogic.verdictDue("2026-11-05", "2026-11-07", questDoneFor = "2026-11-05"))
    }
}
