package com.doordie.do_or_die.blocker

import android.app.AppOpsManager
import android.content.Context
import android.os.Process
import android.provider.Settings

/** The two permissions the watcher needs, both granted by the user in Settings. */
object Permissions {
    /** "Usage access": lets the watcher see which app is in front. */
    fun usageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            ctx.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** "Display over other apps": lets the Penalty Zone appear over a locked app. */
    fun overlay(ctx: Context): Boolean = Settings.canDrawOverlays(ctx)
}
