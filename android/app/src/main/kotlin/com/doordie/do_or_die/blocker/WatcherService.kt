package com.doordie.do_or_die.blocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.doordie.do_or_die.MainActivity
import com.doordie.do_or_die.R
import com.doordie.do_or_die.TrustedTime

/**
 * Watches which app is in front (via usage access) and shows the Penalty
 * Zone over the user's chosen apps while a lock is active. If a day ended
 * without a verdict, opening a chosen app sends the user to Do or Die first.
 *
 * It runs only while it is needed (a lock or phone-free block, a verdict
 * due, or a lock about to start) and otherwise stops, after scheduling exact
 * alarms that wake it at midnight and just before the next lock. Without the
 * exact-alarm permission it keeps running, so enforcement never depends on
 * a wake-up that can't happen.
 *
 * Replaces the accessibility service: payment and banking apps refuse to run
 * while any accessibility service is on, so this blocker uses none.
 */
class WatcherService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastEventQueryAt = 0L
    private var foregroundPackage: String? = null
    private var lastActionAt = 0L
    private var lastHeartbeatAt = 0L
    private var wasBusy = false

    private val loop = object : Runnable {
        override fun run() {
            val ctx = this@WatcherService
            val busy = BlockerState.isLocked(ctx) || BlockerState.needsJudgement(ctx)
            if (busy) check(firstBusyTick = !wasBusy)
            wasBusy = busy
            val now = SystemClock.elapsedRealtime()
            if (now - lastHeartbeatAt >= HEARTBEAT_MS) {
                lastHeartbeatAt = now
                BlockerState.recordHeartbeat(ctx)
            }
            if (!needed(ctx)) {
                // Nothing to watch: wake up again by exact alarm, not by polling.
                if (WakeScheduler.schedule(ctx)) {
                    Log.i(TAG, "watcher idle; stopping until the next alarm")
                    stopSelf()
                    return
                }
            }
            // Fast only while a lock or block is on; a verdict merely due
            // needs a slower check (it acts when a locked app is opened).
            val locked = BlockerState.isLocked(ctx)
            handler.postDelayed(this, if (locked) FAST_MS else if (busy) VERDICT_MS else IDLE_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        startForegroundWithNotice()
        handler.post(loop)
        BlockerState.recordServiceConnected(this)
        Log.i(TAG, "watcher started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        handler.removeCallbacks(loop)
        running = false
        BlockerState.recordServiceDisconnected(this)
        Log.w(TAG, "watcher stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Reads app-switch events since the last check and acts on the latest.
     * On the first busy check (a lock just started, the watcher just woke)
     * it looks back [LOOKBACK_MS], so an app already open when a lock begins
     * is caught at once rather than when the user next switches apps.
     */
    private fun check(firstBusyTick: Boolean) {
        val now = System.currentTimeMillis()
        val from = if (firstBusyTick || lastEventQueryAt == 0L) now - LOOKBACK_MS else lastEventQueryAt
        lastEventQueryAt = now
        val events = UsageMeter.events(this, from, now)
        if (firstBusyTick) {
            foregroundPackage = UsageLogic.foreground(events)
        } else {
            // Only a newly resumed app (or the screen going off) changes it.
            for (e in events) {
                when (e.kind) {
                    UsageLogic.Kind.RESUMED -> foregroundPackage = e.pkg
                    UsageLogic.Kind.SCREEN_OFF -> foregroundPackage = null
                    else -> {}
                }
            }
        }
        val pkg = foregroundPackage ?: return
        if (pkg !in BlockerState.blockedPackages(this)) return

        val nowElapsed = SystemClock.elapsedRealtime()
        if (nowElapsed - lastActionAt < DEBOUNCE_MS) return
        lastActionAt = nowElapsed

        if (BlockerState.needsJudgement(this)) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            )
            BlockerState.recordJudgeRedirect(this)
            Log.i(TAG, "judgement due; opened Do or Die instead of $pkg")
        } else if (BlockerState.isLocked(this)) {
            startActivity(
                Intent(this, BlockActivity::class.java)
                    .putExtra(BlockActivity.EXTRA_PACKAGE, pkg)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            )
            BlockerState.recordBlock(this, pkg)
            Log.i(TAG, "blocked $pkg")
        }
        // The block screen is now in front; until another app resumes, don't
        // keep acting on the same stale event.
        foregroundPackage = null
    }

    private fun startForegroundWithNotice() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Penalty Zone watcher", NotificationManager.IMPORTANCE_MIN).apply {
                description = "Shown only while a lock, a phone-free block or a verdict is pending."
                setShowBadge(false)
            },
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notice: Notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Penalty Zone watcher")
            .setContentText("Watching your locked apps.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTICE_ID, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTICE_ID, notice)
        }
    }

    companion object {
        private const val TAG = "DoOrDieWatcher"
        private const val CHANNEL = "penalty_watcher"
        private const val NOTICE_ID = 4471
        private const val FAST_MS = 700L
        private const val VERDICT_MS = 2_000L
        private const val IDLE_MS = 5_000L
        private const val DEBOUNCE_MS = 1500L
        private const val HEARTBEAT_MS = 10_000L
        private const val LOOKBACK_MS = 60 * 60_000L

        /** True while the service is alive in this process. */
        @Volatile
        var running = false
            private set

        /** Whether the watcher has to be running right now. */
        fun needed(ctx: Context): Boolean = UsageLogic.watcherNeeded(
            locked = BlockerState.isLocked(ctx),
            needsJudgement = BlockerState.needsJudgement(ctx),
            now = TrustedTime.nowMillis(ctx),
            lockStartsAt = BlockerState.lockStartsAt(ctx),
            lockEndsAt = BlockerState.lockEndsAt(ctx),
            exactAlarms = WakeScheduler.canScheduleExact(ctx),
        ) || BlockerState.isFocusLocked(ctx)

        /** Starts the watcher if both permissions it needs are granted. */
        fun startIfAllowed(ctx: Context): Boolean {
            if (!Permissions.usageAccess(ctx) || !Permissions.overlay(ctx)) return false
            return try {
                ctx.startForegroundService(Intent(ctx, WatcherService::class.java))
                true
            } catch (e: Exception) {
                // Android may refuse a start from the background. Never fail
                // silently: say so, so the user can open the app (a start
                // from the foreground is always allowed), and record it for
                // the trial log.
                Log.w(TAG, "could not start watcher: $e")
                BlockerState.recordStartFailure(ctx)
                StartFailureNotice.show(ctx)
                false
            }
        }

        /**
         * After the app pushes new state, at boot and on an alarm: start the
         * watcher if it is needed now, otherwise schedule its wake-ups.
         */
        fun sync(ctx: Context) {
            if (needed(ctx)) {
                startIfAllowed(ctx)
            } else if (!WakeScheduler.schedule(ctx)) {
                startIfAllowed(ctx)
            }
        }
    }
}
