package com.doordie.do_or_die

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrustedTimeTest {
    private val hour = 3_600_000L

    @Test
    fun `network time wins when there is a fix`() {
        assertEquals(500L, TrustedTime.compute(network = 500L, device = 900L, elapsed = 1, anchorWall = 100, anchorElapsed = 0))
    }

    @Test
    fun `setting the clock back cannot rewind trusted time`() {
        // Anchored at wall 10h when elapsed was 1h; now elapsed is 3h.
        val now = TrustedTime.compute(network = null, device = 2 * hour, elapsed = 3 * hour, anchorWall = 10 * hour, anchorElapsed = hour)
        assertEquals(12 * hour, now)
    }

    @Test
    fun `setting the clock forward cannot end a lock early`() {
        val now = TrustedTime.compute(network = null, device = 99 * hour, elapsed = 3 * hour, anchorWall = 10 * hour, anchorElapsed = hour)
        assertEquals(12 * hour, now)
    }

    @Test
    fun `after a reboot the device clock is used, never earlier than the anchor`() {
        assertEquals(10 * hour, TrustedTime.compute(null, device = 5 * hour, elapsed = 60_000, anchorWall = 10 * hour, anchorElapsed = hour))
        assertEquals(11 * hour, TrustedTime.compute(null, device = 11 * hour, elapsed = 60_000, anchorWall = 10 * hour, anchorElapsed = hour))
    }

    @Test
    fun `no anchor and no network - the device clock`() {
        assertEquals(7L, TrustedTime.compute(null, device = 7L, elapsed = 1, anchorWall = 0, anchorElapsed = 0))
    }

    @Test
    fun `re-anchors on a network fix, on first use and after a reboot only`() {
        assertTrue(TrustedTime.shouldReanchor(network = 5L, elapsed = 10, anchorWall = 1, anchorElapsed = 1))
        assertTrue(TrustedTime.shouldReanchor(network = null, elapsed = 10, anchorWall = 0, anchorElapsed = 0))
        assertTrue(TrustedTime.shouldReanchor(network = null, elapsed = 10, anchorWall = 1, anchorElapsed = 50))
        assertFalse(TrustedTime.shouldReanchor(network = null, elapsed = 60, anchorWall = 1, anchorElapsed = 50))
    }
}
