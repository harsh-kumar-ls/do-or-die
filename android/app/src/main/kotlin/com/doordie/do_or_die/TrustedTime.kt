package com.doordie.do_or_die

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings

/**
 * Time the user can't move by changing the phone's clock.
 *
 * Android's network-synced clock is used when it has a fix (Android 13+).
 * Otherwise the last trusted reading is carried forward with the monotonic
 * elapsed-time clock, which the user can't change: setting the clock back
 * can't rescue a failed day and setting it forward can't end a lock. After a
 * reboot (the elapsed clock restarts) it falls back to the device clock, but
 * never earlier than the last trusted time.
 */
object TrustedTime {
    private const val PREFS = "doordie_time"
    private const val KEY_WALL = "anchorWall"
    private const val KEY_ELAPSED = "anchorElapsed"

    /** Network time in ms, or null when Android has no network time yet. */
    fun networkMillis(): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        return try {
            SystemClock.currentNetworkTimeClock().millis()
        } catch (e: Exception) {
            null // DateTimeException: no network time fix yet
        }
    }

    /**
     * Pure: trusted wall time from a network reading, or from the anchor
     * ([anchorWall] seen at [anchorElapsed] on the elapsed clock), or the
     * device clock. Zero anchor means none yet.
     */
    fun compute(network: Long?, device: Long, elapsed: Long, anchorWall: Long, anchorElapsed: Long): Long {
        if (network != null) return network
        if (anchorWall > 0L && elapsed >= anchorElapsed) return anchorWall + (elapsed - anchorElapsed)
        return if (anchorWall > 0L) maxOf(device, anchorWall) else device
    }

    /** Pure: whether a new anchor should be saved after this reading. */
    fun shouldReanchor(network: Long?, elapsed: Long, anchorWall: Long, anchorElapsed: Long): Boolean =
        network != null || anchorWall == 0L || elapsed < anchorElapsed

    fun nowMillis(ctx: Context): Long {
        val p = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val network = networkMillis()
        val elapsed = SystemClock.elapsedRealtime()
        val wall = p.getLong(KEY_WALL, 0L)
        val at = p.getLong(KEY_ELAPSED, 0L)
        val now = compute(network, System.currentTimeMillis(), elapsed, wall, at)
        if (shouldReanchor(network, elapsed, wall, at)) {
            p.edit().putLong(KEY_WALL, now).putLong(KEY_ELAPSED, elapsed).apply()
        }
        return now
    }

    /** Whether "Set time automatically" is on. */
    fun autoTimeEnabled(ctx: Context): Boolean =
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.AUTO_TIME, 1) == 1

    /** Whether "Set time zone automatically" is on. */
    fun autoTimeZoneEnabled(ctx: Context): Boolean =
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.AUTO_TIME_ZONE, 1) == 1

    /**
     * For the app: "network" is the trusted time (network or anchored), so
     * the Dart clock corrects the device clock with it.
     */
    fun snapshot(ctx: Context): Map<String, Any?> {
        val device = System.currentTimeMillis()
        val trusted = nowMillis(ctx)
        return mapOf(
            "network" to trusted,
            "networkFix" to (networkMillis() != null),
            "device" to device,
            "autoTime" to autoTimeEnabled(ctx),
            "autoTimeZone" to autoTimeZoneEnabled(ctx),
        )
    }
}
