package com.doordie.do_or_die.blocker

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.doordie.do_or_die.MainActivity

/**
 * Watches only the apps the user chose to lock. While a lock window is active
 * it shows the Penalty Zone over them. If a day ended without a verdict, it
 * sends the user to Do or Die first so the day gets judged.
 *
 * Never reads window content.
 */
class BlockerAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastActionAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        applyWatchedPackages()
        BlockerState.recordServiceConnected(this)
        Log.i(TAG, "service connected")
    }

    /** Limits events to the chosen apps. Called again whenever the list changes. */
    fun applyWatchedPackages() {
        val info = serviceInfo ?: return
        val packages = BlockerState.blockedPackages(this)
        // An empty array would mean "all apps"; watch nothing instead.
        info.packageNames = if (packages.isEmpty()) arrayOf(NOTHING) else packages.toTypedArray()
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg !in BlockerState.blockedPackages(this)) return

        val judge = BlockerState.needsJudgement(this)
        val locked = BlockerState.isLocked(this)
        if (!judge && !locked) return

        // Content events arrive in bursts; act once per burst.
        val now = SystemClock.elapsedRealtime()
        if (now - lastActionAt < DEBOUNCE_MS) return
        lastActionAt = now

        if (judge) {
            // A day ended unjudged: the verdict comes before anything else.
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            )
            BlockerState.recordJudgeRedirect(this)
            Log.i(TAG, "judgement due; opened Do or Die instead of $pkg")
            return
        }

        startActivity(
            Intent(this, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        )
        BlockerState.recordBlock(this, pkg)
        Log.i(TAG, "blocked $pkg")

        // If the system refused to show the screen, still get the user out.
        handler.postDelayed({
            if (!BlockActivity.isShowing) {
                performGlobalAction(GLOBAL_ACTION_HOME)
                Log.w(TAG, "block screen did not appear for $pkg; sent home instead")
            }
        }, FALLBACK_CHECK_MS)
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        BlockerState.recordServiceDisconnected(this)
        Log.w(TAG, "service unbound")
        return super.onUnbind(intent)
    }

    companion object {
        private const val TAG = "DoOrDieBlocker"
        private const val DEBOUNCE_MS = 1500L
        private const val FALLBACK_CHECK_MS = 1200L
        private const val NOTHING = "com.doordie.do_or_die.none"

        /** The running service, if connected; used to apply list changes live. */
        @Volatile
        var instance: BlockerAccessibilityService? = null
            private set
    }
}
