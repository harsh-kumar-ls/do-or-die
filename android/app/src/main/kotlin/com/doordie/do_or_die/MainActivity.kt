package com.doordie.do_or_die

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import com.doordie.do_or_die.blocker.BlockerAccessibilityService
import com.doordie.do_or_die.blocker.BlockerState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doordie/blocker")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        BlockerState.status(this) + ("serviceEnabled" to isServiceEnabled()),
                    )
                    "setBlockedPackages" -> {
                        val packages = call.argument<List<String>>("packages").orEmpty().toSet()
                        BlockerState.setBlockedPackages(this, packages)
                        BlockerAccessibilityService.instance?.applyWatchedPackages()
                        result.success(null)
                    }
                    "setLockWindow" -> {
                        val start = call.argument<Number>("startsAt")?.toLong() ?: 0L
                        val end = call.argument<Number>("endsAt")?.toLong() ?: 0L
                        BlockerState.setLockWindow(this, start, end)
                        result.success(null)
                    }
                    "clearLockWindow" -> {
                        BlockerState.clearLockWindow(this)
                        result.success(null)
                    }
                    "setJudgeDueFrom" -> {
                        BlockerState.setJudgeDueFrom(this, call.argument<String>("day"))
                        result.success(null)
                    }
                    "installedApps" -> thread {
                        val apps = installedApps()
                        main.post { result.success(apps) }
                    }
                    "protectedPackages" -> result.success(protectedPackages().toList())
                    "trustedTime" -> result.success(TrustedTime.snapshot(this))
                    "openDateSettings" -> {
                        startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                        result.success(null)
                    }
                    "startLock" -> {
                        BlockerState.startLock(this, call.argument<Int>("minutes") ?: 0)
                        result.success(null)
                    }
                    "stopLock" -> {
                        BlockerState.stopLock(this)
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val me = ComponentName(this, BlockerAccessibilityService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    /** Launchable apps with label and a small PNG icon, minus protected ones. */
    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val protectedSet = protectedPackages()
        return pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.packageName to it }
            .distinctBy { it.first }
            .filter { it.first !in protectedSet }
            .map { (pkg, info) ->
                mapOf(
                    "package" to pkg,
                    "label" to info.loadLabel(pm).toString(),
                    "icon" to iconPng(info.loadIcon(pm)),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun iconPng(drawable: android.graphics.drawable.Drawable): ByteArray {
        val size = (40 * resources.displayMetrics.density).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
    }

    /** Apps that must never be locked on this device: phone, SMS, launcher, settings, this app. */
    private fun protectedPackages(): Set<String> {
        val pm = packageManager
        val out = mutableSetOf(packageName, "com.android.settings")
        (getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)
            ?.defaultDialerPackage?.let { out += it }
        Telephony.Sms.getDefaultSmsPackage(this)?.let { out += it }
        pm.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName?.let { out += it }
        return out
    }
}
