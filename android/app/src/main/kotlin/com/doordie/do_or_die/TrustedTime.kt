package com.doordie.do_or_die

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings

/**
 * Time the user can't move by changing the phone's clock. Uses Android's
 * network-synced clock when it has a fix, otherwise the device clock.
 */
object TrustedTime {
    /** Network time in ms, or null when Android has no network time yet. */
    fun networkMillis(): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        return try {
            SystemClock.currentNetworkTimeClock().millis()
        } catch (e: Exception) {
            null // DateTimeException: no network time fix yet
        }
    }

    fun nowMillis(): Long = networkMillis() ?: System.currentTimeMillis()

    /** Whether "Set time automatically" is on. */
    fun autoTimeEnabled(ctx: Context): Boolean =
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.AUTO_TIME, 1) == 1

    fun snapshot(ctx: Context): Map<String, Any?> = mapOf(
        "network" to networkMillis(),
        "device" to System.currentTimeMillis(),
        "autoTime" to autoTimeEnabled(ctx),
    )
}
