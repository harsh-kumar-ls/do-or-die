package com.doordie.do_or_die.blocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
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

/**
 * Watches which app is in front (via usage access) and shows the Penalty
 * Zone over the user's chosen apps while a lock is active. If a day ended
 * without a verdict, opening a chosen app sends the user to Do or Die first.
 *
 * Replaces the accessibility service: payment and banking apps refuse to run
 * while any accessibility service is on, so this blocker uses none.
 */
class WatcherService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastEventQueryAt = 0L
    private var foregroundPackage: String? = null
    private var lastActionAt = 0L

    private val loop = object : Runnable {
        override fun run() {
            val busy = BlockerState.isLocked(this@WatcherService) ||
                BlockerState.needsJudgement(this@WatcherService)
            if (busy) check()
            // Fast while it matters, slow otherwise (cheap: no query when idle).
            handler.postDelayed(this, if (busy) FAST_MS else IDLE_MS)
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

    /** Reads app-switch events since the last check and acts on the latest. */
    private fun check() {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val from = if (lastEventQueryAt == 0L) now - 10_000 else lastEventQueryAt
        lastEventQueryAt = now
        val events = usm.queryEvents(from, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            if (e.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                foregroundPackage = e.packageName
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
                description = "Keeps the Penalty Zone ready. Android requires this notice."
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
        private const val IDLE_MS = 5_000L
        private const val DEBOUNCE_MS = 1500L

        /** True while the service is alive in this process. */
        @Volatile
        var running = false
            private set

        /** Starts the watcher if both permissions it needs are granted. */
        fun startIfAllowed(ctx: Context): Boolean {
            if (!Permissions.usageAccess(ctx) || !Permissions.overlay(ctx)) return false
            return try {
                ctx.startForegroundService(Intent(ctx, WatcherService::class.java))
                true
            } catch (e: Exception) {
                Log.w(TAG, "could not start watcher: $e")
                false
            }
        }
    }
}
