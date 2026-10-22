package com.doordie.do_or_die.blocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts the watcher after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            -> WatcherService.startIfAllowed(context)
        }
    }
}
