package com.doordie.do_or_die.blocker

import com.doordie.do_or_die.TrustedTime
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

/**
 * Shown in place of a locked app, in one of three looks from the Claude
 * Design prototype (design/claude-design/penalty.html): Penalty Zone (red),
 * Dungeon Penalty (crimson and gold) and phone-free block (blue).
 */
class BlockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var countdown: TextView
    private lateinit var caption: TextView
    private lateinit var releaseLine: TextView
    private var mode = "penalty"

    private val tick = object : Runnable {
        override fun run() {
            val ctx = this@BlockActivity
            // Lock over, or a short release just started: get out of the way.
            if (!BlockerState.isLocked(ctx)) {
                finish()
                return
            }
            val penalty = BlockerState.isPenaltyLocked(ctx)
            if (penalty) {
                countdown.text = format(BlockerState.lockEndsAt(ctx) - TrustedTime.nowMillis(ctx))
                countdown.setTextSize(TypedValue.COMPLEX_UNIT_SP, 52f)
            } else {
                countdown.text = "BLOCK RUNNING"
                countdown.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            }
            val used = BlockerState.releases(ctx)
            releaseLine.text = if (used == 0 || !penalty) "" else
                "RELEASES USED: $used · ${used * 15} MIN"
            handler.postDelayed(this, 1000)
        }
    }

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    private fun font(name: String): Typeface = try {
        Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/$name")
    } catch (e: Exception) {
        Typeface.MONOSPACE
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mode = BlockerState.mode(this)
        val pkg = intent.getStringExtra(EXTRA_PACKAGE)
        val appName = pkg?.let {
            try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(it, 0)).toString()
            } catch (e: Exception) { null }
        } ?: "This app"

        val acc = Color.parseColor(when (mode) { "dungeon" -> "#D7263D"; "focus" -> "#4FB3FF"; else -> "#FF3B4A" })
        val title = Color.parseColor(when (mode) { "dungeon" -> "#F5C96A"; "focus" -> "#A9DCFF"; else -> "#FF5562" })
        val acc2 = Color.parseColor(when (mode) { "dungeon" -> "#F5C96A"; "focus" -> "#A9DCFF"; else -> "#FF8790" })
        val bg = Color.parseColor(when (mode) { "dungeon" -> "#060102"; "focus" -> "#05070D"; else -> "#090204" })
        val glow = Color.parseColor(when (mode) { "dungeon" -> "#1D0308"; "focus" -> "#0B1730"; else -> "#2A050A" })
        val ink = Color.parseColor("#DBE7FF")
        val dim = Color.parseColor("#7D8BA8")
        val head = font("ChakraPetch-Bold.ttf")
        val mono = font("JetBrainsMono.ttf")

        // App icon, greyed, with a lock badge.
        val icon = ImageView(this).apply {
            try { setImageDrawable(packageManager.getApplicationIcon(pkg ?: "")) } catch (e: Exception) {}
            colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
            alpha = .55f
        }
        val badge = TextView(this).apply {
            text = "LOCKED"
            setTextColor(acc)
            textSize = 9f
            typeface = mono
            letterSpacing = .12f
            gravity = Gravity.CENTER
            background = GradientDrawable().apply { setColor(bg); setStroke(dp(1.5f).toInt(), acc) }
            setPadding(dp(6f).toInt(), dp(3f).toInt(), dp(6f).toInt(), dp(3f).toInt())
        }
        val iconBox = FrameLayout(this).apply {
            addView(icon, FrameLayout.LayoutParams(dp(96f).toInt(), dp(96f).toInt()))
            addView(badge, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.END,
            ))
        }

        fun tv(s: String, color: Int, size: Float, tf: Typeface, spacing: Float = 0f) = TextView(this).apply {
            this.text = s
            setTextColor(color)
            textSize = size
            typeface = tf
            letterSpacing = spacing
            gravity = Gravity.CENTER
        }

        val titleView = tv(
            when (mode) { "dungeon" -> "[ DUNGEON PENALTY ]"; "focus" -> "[ PHONE-FREE BLOCK ]"; else -> "[ ACCESS DENIED ]" },
            title, 22f, head, .2f,
        ).apply { setShadowLayer(dp(10f), 0f, 0f, acc) }
        val reason = tv(
            when (mode) {
                "dungeon" -> "$appName is sealed. The Dungeon was not cleared."
                "focus" -> "$appName is closed while your block runs."
                else -> "$appName is locked. The daily quest was failed."
            },
            ink, 14f, mono,
        ).apply { setLineSpacing(0f, 1.4f); setPadding(0, dp(14f).toInt(), 0, 0) }
        countdown = tv("", Color.WHITE, 52f, mono).apply {
            setShadowLayer(dp(10f), 0f, 0f, acc)
            setPadding(0, dp(18f).toInt(), 0, 0)
        }
        caption = tv(
            when (mode) { "dungeon" -> "UNTIL THE SEAL BREAKS"; "focus" -> "END IT IN DO OR DIE"; else -> "UNTIL ACCESS IS RESTORED" },
            acc2, 12f, head, .2f,
        ).apply { setPadding(0, dp(6f).toInt(), 0, 0) }
        val fine = tv(
            when (mode) {
                "dungeon" -> "Double lock. Clear your Dungeon debt in Do or Die."
                "focus" -> "Ending the block early stops your progress toward today's quest."
                else -> "Emergency release is in Do or Die · Penalty."
            },
            dim, 11f, mono,
        ).apply { setLineSpacing(0f, 1.4f); setPadding(0, dp(14f).toInt(), 0, 0) }
        releaseLine = tv("", acc2, 11f, mono, .1f).apply { setPadding(0, dp(8f).toInt(), 0, 0) }

        val leave = tv("LEAVE", acc2, 15f, head, .3f).apply {
            background = GradientDrawable().apply {
                setColor(Color.argb(18, Color.red(acc), Color.green(acc), Color.blue(acc)))
                setStroke(dp(1f).toInt(), acc)
            }
            minHeight = dp(56f).toInt()
            setOnClickListener { goHome() }
        }

        val middle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(iconBox, LinearLayout.LayoutParams(dp(104f).toInt(), dp(104f).toInt()).apply { bottomMargin = dp(18f).toInt() })
            addView(titleView)
            addView(reason)
            addView(countdown)
            addView(caption)
            addView(fine)
            addView(releaseLine)
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(glow, bg, bg))
            setPadding(dp(24f).toInt(), dp(44f).toInt(), dp(24f).toInt(), dp(40f).toInt())
            addView(middle, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
            addView(leave, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        }
        setContentView(root)
        window.statusBarColor = bg
        window.navigationBarColor = bg

        // Enter: the icon drops in, then the rest fades up.
        iconBox.alpha = 0f
        iconBox.translationY = -dp(12f)
        iconBox.animate().alpha(1f).translationY(0f).setDuration(300).start()
        for ((i, v) in listOf<View>(titleView, reason, countdown, caption, fine).withIndex()) {
            v.alpha = 0f
            v.animate().alpha(1f).setStartDelay(200L + i * 60L).setDuration(250).start()
        }

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
        const val EXTRA_PACKAGE = "package"

        /** Read by the service to check the screen actually appeared. */
        @Volatile
        var isShowing = false
            private set
    }
}
