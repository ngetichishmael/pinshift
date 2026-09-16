package com.pinshift.pinshift

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat

object MockLocationProbe {
    fun developerOptionsEnabled(context: Context): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0,
            ) == 1
        } catch (_: Exception) {
            false
        }
    }

    fun mockAppSelected(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_MOCK_LOCATION,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_MOCK_LOCATION,
                    Process.myUid(),
                    context.packageName,
                )
            }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun fineLocationGranted(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun notificationsGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun statusMap(
        context: Context,
        simulating: Boolean,
        latitude: Double? = null,
        longitude: Double? = null,
        accuracyMeters: Double? = null,
        jitterMeters: Double? = null,
        spoofHardening: Boolean = false,
        error: String? = null,
    ): Map<String, Any?> {
        return mapOf(
            "developerOptionsEnabled" to developerOptionsEnabled(context),
            "mockAppSelected" to mockAppSelected(context),
            "locationPermissionGranted" to fineLocationGranted(context),
            "notificationPermissionGranted" to notificationsGranted(context),
            "simulating" to simulating,
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracyMeters" to accuracyMeters,
            "jitterMeters" to jitterMeters,
            "spoofHardening" to spoofHardening,
            "error" to error,
        )
    }
}
