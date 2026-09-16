package com.pinshift.pinshift

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MockLocationPlugin(
    private val activity: MainActivity,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var events: EventChannel.EventSink? = null
    private val hubListener: (Map<String, Any?>) -> Unit = { snapshot ->
        activity.runOnUiThread {
            if (!activity.isDestroyed) {
                events?.success(snapshot)
            }
        }
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(currentStatus())
            "start" -> start(call, result)
            "stop" -> {
                activity.startService(MockLocationService.stopIntent(activity))
                result.success(currentStatus())
            }
            "openDeveloperSettings" -> {
                activity.startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
                result.success(null)
            }
            "openAppSettings" -> {
                activity.startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activity.packageName, null),
                    ),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
        SimulationHub.addListener(hubListener)
        events?.success(currentStatus())
    }

    override fun onCancel(arguments: Any?) {
        SimulationHub.removeListener(hubListener)
        events = null
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        if (latitude == null || longitude == null) {
            result.error("invalid_args", "latitude and longitude are required.", null)
            return
        }
        if (latitude !in -90.0..90.0 || longitude !in -180.0..180.0) {
            result.error("invalid_args", "Coordinates are out of range.", null)
            return
        }
        if (!MockLocationProbe.developerOptionsEnabled(activity)) {
            result.error("developer_options", "Enable Developer options first.", currentStatus())
            return
        }
        if (!MockLocationProbe.mockAppSelected(activity)) {
            result.error("not_mock_app", MockLocationService.ERROR_NOT_MOCK_APP, currentStatus())
            return
        }
        if (!MockLocationProbe.fineLocationGranted(activity)) {
            result.error(
                "location_permission",
                MockLocationService.ERROR_LOCATION_PERMISSION,
                currentStatus(),
            )
            return
        }

        val accuracy = call.argument<Double>("accuracyMeters") ?: 5.0
        val jitter = call.argument<Double>("jitterMeters") ?: 4.0
        val spoofHardening = call.argument<Boolean>("spoofHardening") ?: false
        val altitude = call.argument<Double>("altitudeMeters") ?: 0.0
        ContextCompat.startForegroundService(
            activity,
            MockLocationService.startIntent(
                activity, latitude, longitude, accuracy, jitter,
                spoofHardening = spoofHardening,
                altitudeMeters = altitude,
            ),
        )
        result.success(
            MockLocationProbe.statusMap(
                context = activity,
                simulating = true,
                latitude = latitude,
                longitude = longitude,
                accuracyMeters = accuracy,
                jitterMeters = jitter,
                spoofHardening = spoofHardening,
            ),
        )
    }

    private fun currentStatus(): Map<String, Any?> {
        val published = SimulationHub.snapshot
        if (published.isNotEmpty()) {
            return published
        }
        return MockLocationProbe.statusMap(activity, simulating = false)
    }

    companion object {
        const val METHOD_CHANNEL = "com.pinshift.pinshift/mock_location"
        const val EVENT_CHANNEL = "com.pinshift.pinshift/mock_location_events"
    }
}
