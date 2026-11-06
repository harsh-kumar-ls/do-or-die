package com.doordie.do_or_die.blocker

import com.doordie.do_or_die.TrustedTime
import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Enforcement state pushed from the app, persisted so it survives the app
 * being killed and the phone rebooting. Read by the accessibility service.
 */
object BlockerState {
    private const val PREFS = "doordie_blocker"
    private const val KEY_PACKAGES = "blockedPackages"
    private const val KEY_LOCK_STARTS_AT = "lockStartsAt"
    private const val KEY_LOCK_ENDS_AT = "lockEndsAt"
    private const val KEY_RELEASED_UNTIL = "releasedUntil"
    private const val KEY_RELEASES = "releases"
    private const val KEY_MODE = "lockMode"
    private const val KEY_FOCUS_STARTS_AT = "focusStartsAt"
    private const val KEY_FOCUS_ENDS_AT = "focusEndsAt"
    private const val KEY_JUDGE_DUE_FROM = "judgeDueFrom"
    private const val KEY_LAST_CONNECTED_AT = "lastConnectedAt"
    private const val KEY_HEARTBEAT_AT = "lastHeartbeatAt"
    private const val KEY_LAST_DISCONNECTED_AT = "lastDisconnectedAt"
    private const val KEY_BLOCK_COUNT = "blockCount"
    private const val KEY_LAST_BLOCKED_PACKAGE = "lastBlockedPackage"
    private const val KEY_LAST_BLOCK_AT = "lastBlockAt"
    private const val KEY_EMERGENCY_STOPS = "emergencyStops"
    private const val KEY_JUDGE_REDIRECTS = "judgeRedirects"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Apps the user chose to lock. Empty until the app pushes a list. */
    fun blockedPackages(ctx: Context): Set<String> =
        prefs(ctx).getStringSet(KEY_PACKAGES, emptySet())?.toSet() ?: emptySet()

    fun setBlockedPackages(ctx: Context, packages: Set<String>) {
        prefs(ctx).edit().putStringSet(KEY_PACKAGES, packages.toSet()).commit()
    }

    fun lockStartsAt(ctx: Context): Long = prefs(ctx).getLong(KEY_LOCK_STARTS_AT, 0L)

    fun lockEndsAt(ctx: Context): Long = prefs(ctx).getLong(KEY_LOCK_ENDS_AT, 0L)

    /** True while the current time is inside the lock window. */
    fun releasedUntil(ctx: Context): Long = prefs(ctx).getLong(KEY_RELEASED_UNTIL, 0L)

    /** Short releases taken during the current lock. */
    fun releases(ctx: Context): Int = prefs(ctx).getInt(KEY_RELEASES, 0)

    /** Inside the penalty window and not in a short release. */
    fun isPenaltyLocked(ctx: Context): Boolean {
        val now = TrustedTime.nowMillis()
        val inWindow = now >= lockStartsAt(ctx) && now < lockEndsAt(ctx)
        return inWindow && now >= releasedUntil(ctx)
    }

    /** A phone-free block the user started is running. */
    fun isFocusLocked(ctx: Context): Boolean {
        val p = prefs(ctx)
        val now = TrustedTime.nowMillis()
        return now >= p.getLong(KEY_FOCUS_STARTS_AT, 0L) && now < p.getLong(KEY_FOCUS_ENDS_AT, 0L)
    }

    /** Chosen apps are locked right now, by a penalty or a phone-free block. */
    fun isLocked(ctx: Context): Boolean = isPenaltyLocked(ctx) || isFocusLocked(ctx)

    /** Kept apart from the penalty window so neither can erase the other. */
    fun setFocusWindow(ctx: Context, startsAt: Long, endsAt: Long) {
        prefs(ctx).edit()
            .putLong(KEY_FOCUS_STARTS_AT, startsAt)
            .putLong(KEY_FOCUS_ENDS_AT, endsAt)
            .commit()
    }

    /** The window the rules engine scheduled. Its start is never shown to the user. */
    fun setLockWindow(
        ctx: Context,
        startsAt: Long,
        endsAt: Long,
        releasedUntil: Long = 0L,
        releases: Int = 0,
        mode: String = "penalty",
    ) {
        prefs(ctx).edit()
            .putString(KEY_MODE, mode)
            .putLong(KEY_LOCK_STARTS_AT, startsAt)
            .putLong(KEY_LOCK_ENDS_AT, endsAt)
            .putLong(KEY_RELEASED_UNTIL, releasedUntil)
            .putInt(KEY_RELEASES, releases)
            .commit()
    }

    /**
     * What the block screen shows: "penalty", "dungeon" (the day after a
     * failed Dungeon floor) or "focus" (only a phone-free block is running).
     */
    fun mode(ctx: Context): String =
        if (!isPenaltyLocked(ctx) && isFocusLocked(ctx)) "focus"
        else prefs(ctx).getString(KEY_MODE, "penalty") ?: "penalty"

    fun clearLockWindow(ctx: Context) {
        prefs(ctx).edit()
            .putString(KEY_MODE, "penalty")
            .putLong(KEY_LOCK_STARTS_AT, 0L)
            .putLong(KEY_LOCK_ENDS_AT, 0L)
            .putLong(KEY_RELEASED_UNTIL, 0L)
            .putInt(KEY_RELEASES, 0)
            .commit()
    }

    /** Starts a lock now, for the diagnostics screen. */
    fun startLock(ctx: Context, minutes: Int) {
        val now = TrustedTime.nowMillis()
        setLockWindow(ctx, now, now + minutes * 60_000L)
    }

    /** Diagnostics escape: ends the lock now and counts it. */
    fun stopLock(ctx: Context) {
        val p = prefs(ctx)
        val wasLocked = isPenaltyLocked(ctx)
        clearLockWindow(ctx)
        setFocusWindow(ctx, 0L, 0L)
        if (wasLocked) p.edit().putInt(KEY_EMERGENCY_STOPS, p.getInt(KEY_EMERGENCY_STOPS, 0) + 1).commit()
    }

    /**
     * The first day the app has not judged yet (yyyy-MM-dd). When that day is
     * before today, a day ended without a verdict, so opening a locked app
     * sends the user to Do or Die first.
     */
    fun setJudgeDueFrom(ctx: Context, isoDay: String?) {
        prefs(ctx).edit().putString(KEY_JUDGE_DUE_FROM, isoDay).commit()
    }

    fun needsJudgement(ctx: Context): Boolean {
        val due = prefs(ctx).getString(KEY_JUDGE_DUE_FROM, null) ?: return false
        if (!ISO_DAY.matches(due)) return false
        // yyyy-MM-dd strings sort in date order.
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(TrustedTime.nowMillis()))
        return due < today
    }

    private val ISO_DAY = Regex("""\d{4}-\d{2}-\d{2}""")

    fun recordServiceConnected(ctx: Context) {
        prefs(ctx).edit().putLong(KEY_LAST_CONNECTED_AT, System.currentTimeMillis()).apply()
    }

    /** The watcher writes this while it runs, so a gap can be measured. */
    fun recordHeartbeat(ctx: Context) {
        prefs(ctx).edit().putLong(KEY_HEARTBEAT_AT, System.currentTimeMillis()).apply()
    }

    fun lastHeartbeat(ctx: Context): Long = prefs(ctx).getLong(KEY_HEARTBEAT_AT, 0L)

    fun recordServiceDisconnected(ctx: Context) {
        prefs(ctx).edit().putLong(KEY_LAST_DISCONNECTED_AT, System.currentTimeMillis()).apply()
    }

    fun recordBlock(ctx: Context, pkg: String) {
        val p = prefs(ctx)
        p.edit()
            .putInt(KEY_BLOCK_COUNT, p.getInt(KEY_BLOCK_COUNT, 0) + 1)
            .putString(KEY_LAST_BLOCKED_PACKAGE, pkg)
            .putLong(KEY_LAST_BLOCK_AT, System.currentTimeMillis())
            .apply()
    }

    fun recordJudgeRedirect(ctx: Context) {
        val p = prefs(ctx)
        p.edit().putInt(KEY_JUDGE_REDIRECTS, p.getInt(KEY_JUDGE_REDIRECTS, 0) + 1).apply()
    }

    fun status(ctx: Context): Map<String, Any?> {
        val p = prefs(ctx)
        return mapOf(
            "now" to System.currentTimeMillis(),
            "lockStartsAt" to lockStartsAt(ctx),
            "lockEndsAt" to lockEndsAt(ctx),
            "releasedUntil" to releasedUntil(ctx),
            "releases" to releases(ctx),
            "mode" to mode(ctx),
            "locked" to isLocked(ctx),
            "focusLocked" to isFocusLocked(ctx),
            "blockedPackages" to blockedPackages(ctx).sorted(),
            "needsJudgement" to needsJudgement(ctx),
            "lastConnectedAt" to p.getLong(KEY_LAST_CONNECTED_AT, 0L),
            "lastDisconnectedAt" to p.getLong(KEY_LAST_DISCONNECTED_AT, 0L),
            "blockCount" to p.getInt(KEY_BLOCK_COUNT, 0),
            "lastBlockedPackage" to p.getString(KEY_LAST_BLOCKED_PACKAGE, null),
            "lastBlockAt" to p.getLong(KEY_LAST_BLOCK_AT, 0L),
            "emergencyStops" to p.getInt(KEY_EMERGENCY_STOPS, 0),
            "judgeRedirects" to p.getInt(KEY_JUDGE_REDIRECTS, 0),
        )
    }
}
