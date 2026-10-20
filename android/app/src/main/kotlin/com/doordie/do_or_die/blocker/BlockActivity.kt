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

    private val tick = object : Runnable {
        override fun run() {
            val remaining = BlockerState.lockEndsAt(this@BlockActivity) - TrustedTime.nowMillis()
            if (remaining <= 0) {
                finish()
                return
            }
            countdown.text = format(remaining)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val red = Color.parseColor("#FF3B4A")
        val dim = Color.parseColor("#8A93A6")

        val title = TextView(this).apply {
            text = "[ PENALTY ZONE ]"
            setTextColor(red)
            textSize = 26f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
        }
        val body = TextView(this).apply {
            text = "Access denied.\nThe quest was not completed."
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
        val leave = Button(this).apply {
            text = "Leave"
            setOnClickListener { goHome() }
        }

        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#07080C"))
                setPadding(48, 48, 48, 48)
                addView(title)
                addView(body)
                addView(countdown)
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
