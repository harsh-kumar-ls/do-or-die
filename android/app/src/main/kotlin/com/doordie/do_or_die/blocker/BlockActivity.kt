package com.doordie.do_or_die.blocker

import com.doordie.do_or_die.TrustedTime
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

/** Full-screen Penalty Zone shown in place of a blocked app. */
class BlockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var countdown: TextView

    private lateinit var releaseLine: TextView

    private val tick = object : Runnable {
        override fun run() {
            val ctx = this@BlockActivity
            // Lock over, or a short release just started: get out of the way.
            if (!BlockerState.isLocked(ctx)) {
                finish()
                return
            }
            val penalty = BlockerState.isPenaltyLocked(ctx)
            countdown.textSize = if (penalty) 40f else 16f
            countdown.text = if (penalty)
                format(BlockerState.lockEndsAt(ctx) - TrustedTime.nowMillis())
            else "Pause the block in Do or Die to end it."
            val used = BlockerState.releases(ctx)
            releaseLine.text = if (used == 0) "" else
                "Releases used: $used (${used * 15} min)"
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val mode = BlockerState.mode(this)
        val red = Color.parseColor(
            when (mode) {
                "dungeon" -> "#E0B44C"
                "focus" -> "#4FC3F7"
                else -> "#FF3B4A"
            },
        )
        val dim = Color.parseColor("#8A93A6")

        val title = TextView(this).apply {
            text = when (mode) {
                "dungeon" -> "[ DUNGEON PENALTY ]"
                "focus" -> "[ PHONE-FREE BLOCK ]"
                else -> "[ PENALTY ZONE ]"
            }
            setTextColor(red)
            textSize = 26f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
        }
        val body = TextView(this).apply {
            text = when (mode) {
                "dungeon" -> "Access denied.\nThe Dungeon was not cleared."
                "focus" -> "Access denied.\nA phone-free block is running."
                else -> "Access denied.\nThe quest was not completed."
            }
            setTextColor(dim)
            textSize = 16f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 32)
        }
        countdown = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 40f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
        }
        releaseLine = TextView(this).apply {
            setTextColor(red)
            textSize = 14f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 24)
        }
        val leave = Button(this).apply {
            text = "Leave"
            setOnClickListener { goHome() }
        }

        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor(if (mode == "dungeon") "#0E0406" else "#07080C"))
                setPadding(48, 48, 48, 48)
                addView(title)
                addView(body)
                addView(countdown)
                addView(releaseLine)
                addView(leave)
            },
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { goHome() }
        }
    }

    override fun onResume() {
        super.onResume()
        isShowing = true
        handler.post(tick)
    }

    override fun onPause() {
        isShowing = false
        handler.removeCallbacks(tick)
        super.onPause()
    }

    // This screen sits on top of the blocked app, so Back must never reveal it.
    @Deprecated("Needed below API 33")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    private fun format(ms: Long): String {
        val total = ms / 1000
        return "%02d:%02d:%02d".format(total / 3600, (total % 3600) / 60, total % 60)
    }

    companion object {
        /** Read by the service to check the screen actually appeared. */
        @Volatile
        var isShowing = false
            private set
    }
}
