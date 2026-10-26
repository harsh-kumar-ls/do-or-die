package com.doordie.do_or_die

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import com.doordie.do_or_die.blocker.BlockerState
import com.doordie.do_or_die.blocker.Permissions
import com.doordie.do_or_die.blocker.WatcherService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opening the app always (re)starts the watcher if it's allowed to run.
        WatcherService.startIfAllowed(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doordie/blocker")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        BlockerState.status(this) + ("serviceEnabled" to watcherReady()),
                    )
                    "setBlockedPackages" -> {
                        val packages = call.argument<List<String>>("packages").orEmpty().toSet()
                        BlockerState.setBlockedPackages(this, packages)
                        result.success(null)
                    }
                    "setLockWindow" -> {
                        val start = call.argument<Number>("startsAt")?.toLong() ?: 0L
                        val end = call.argument<Number>("endsAt")?.toLong() ?: 0L
                        val releasedUntil = call.argument<Number>("releasedUntil")?.toLong() ?: 0L
                        val releases = call.argument<Number>("releases")?.toInt() ?: 0
                        val mode = call.argument<String>("mode") ?: "penalty"
                        BlockerState.setLockWindow(this, start, end, releasedUntil, releases, mode)
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
                    "systemStatus" -> result.success(
                        mapOf(
                            "serviceEnabled" to watcherReady(),
                            "usageAccess" to Permissions.usageAccess(this),
                            "overlay" to Permissions.overlay(this),
                            "watcherRunning" to WatcherService.running,
                            "batteryExempt" to isBatteryExempt(),
                            "autoTime" to TrustedTime.autoTimeEnabled(this),
                        ),
                    )
                    "requestBatteryExemption" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "startWatcher" -> {
                        WatcherService.startIfAllowed(this)
                        // Give the service a moment to report itself running.
                        main.postDelayed({ result.success(watcherReady()) }, 400)
                    }
                    "requestUsageAccess" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "requestOverlay" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "setFocusWindow" -> {
                        BlockerState.setFocusWindow(
                            this,
                            call.argument<Number>("startsAt")?.toLong() ?: 0L,
                            call.argument<Number>("endsAt")?.toLong() ?: 0L,
                        )
                        result.success(null)
                    }
                    "minutesUsed" -> thread {
                        val packages = call.argument<List<String>>("packages").orEmpty().toSet()
                        val from = call.argument<Number>("from")?.toLong() ?: 0L
                        val to = call.argument<Number>("to")?.toLong() ?: 0L
                        val ms = com.doordie.do_or_die.blocker.UsageMeter
                            .foregroundMillis(this, packages, from, to)
                        main.post { result.success(if (ms < 0) null else (ms / 60_000L).toInt()) }
                    }
                    "startLock" -> {
                        BlockerState.startLock(this, call.argument<Int>("minutes") ?: 0)
                        result.success(null)
                    }
                    "stopLock" -> {
                        BlockerState.stopLock(this)
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

    private fun isBatteryExempt(): Boolean =
        (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .isIgnoringBatteryOptimizations(packageName)

    /** Both permissions granted and the watcher alive: locks can be enforced. */
    private fun watcherReady(): Boolean =
        Permissions.usageAccess(this) && Permissions.overlay(this) && WatcherService.running

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
