package com.crimeatravel.tourism_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePushNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "setAppIcon" -> {
                    val variant = call.argument<String>("variant")
                    val alias = ICON_ALIASES[variant]
                    if (alias == null) {
                        result.error("unknown_icon", "Unknown icon variant: $variant", null)
                    } else {
                        applyIconAlias(alias)
                        result.success(null)
                    }
                }
                "currentAppIcon" -> result.success(currentIconVariant())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Switches the launcher icon by enabling one alias and disabling the rest.
     *
     * The new one is enabled first: if the app were left with every alias
     * disabled — even for an instant, or because the process died in between —
     * it would vanish from the launcher with no way back in.
     *
     * DONT_KILL_APP keeps the process alive; some launchers still take a few
     * seconds to redraw, which is a platform behaviour rather than a bug here.
     */
    private fun applyIconAlias(enabled: String) {
        val manager = packageManager
        manager.setComponentEnabledSetting(
            ComponentName(this, enabled),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (alias in ICON_ALIASES.values) {
            if (alias == enabled) continue
            manager.setComponentEnabledSetting(
                ComponentName(this, alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun currentIconVariant(): String {
        val manager = packageManager
        for ((variant, alias) in ICON_ALIASES) {
            val state = manager.getComponentEnabledSetting(ComponentName(this, alias))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return variant
            }
        }
        // Nothing explicitly enabled means the manifest default is in force.
        return DEFAULT_ICON
    }

    private fun openNotificationSettings() {
        val intent = Intent().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", packageName, null)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun ensurePushNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID,
            "CrimeaTrip",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Системные уведомления CrimeaTrip"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val PUSH_CHANNEL_ID = "crimeatrip_push"
        const val SETTINGS_CHANNEL = "com.crimeatravel.tourism_mobile/settings"
        const val DEFAULT_ICON = "default"
        val ICON_ALIASES = linkedMapOf(
            "default" to "com.crimeatravel.tourism_mobile.MainActivityDefault",
            "sunset" to "com.crimeatravel.tourism_mobile.MainActivitySunset",
            "sea" to "com.crimeatravel.tourism_mobile.MainActivitySea",
            "night" to "com.crimeatravel.tourism_mobile.MainActivityNight",
        )
    }
}
