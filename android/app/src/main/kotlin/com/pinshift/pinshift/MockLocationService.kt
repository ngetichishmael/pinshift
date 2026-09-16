package com.pinshift.pinshift

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

class MockLocationService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val tick =
        object : Runnable {
            override fun run() {
                pushLocation()
                handler.postDelayed(this, TICK_MS)
            }
        }

    private lateinit var locationManager: LocationManager
    private val enabledProviders = mutableListOf<String>()

    private var latitude = 0.0
    private var longitude = 0.0
    private var accuracyMeters = 5.0
    private var jitterMeters = 4.0
    private var spoofHardening = false
    private var baseAltitude = 0.0
    private var running = false

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        ensureChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSimulation()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val source = intent ?: getSharedPreferences(PREFS, MODE_PRIVATE).let { prefs ->
                    if (!prefs.getBoolean(KEY_RUNNING, false)) {
                        stopSelf()
                        return START_NOT_STICKY
                    }
                    Intent().apply {
                        putExtra(EXTRA_LAT, prefs.getFloat(KEY_LAT, 0f).toDouble())
                        putExtra(EXTRA_LNG, prefs.getFloat(KEY_LNG, 0f).toDouble())
                        putExtra(EXTRA_ACCURACY, prefs.getFloat(KEY_ACCURACY, 5f).toDouble())
                        putExtra(EXTRA_JITTER, prefs.getFloat(KEY_JITTER, 4f).toDouble())
                        putExtra(EXTRA_SPOOF_HARDENING, prefs.getBoolean(KEY_SPOOF_HARDENING, false))
                        putExtra(EXTRA_ALTITUDE, prefs.getFloat(KEY_ALTITUDE, 0f).toDouble())
                    }
                }
                startSimulation(source)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        tearDownProviders()
        running = false
        publish(error = null)
        super.onDestroy()
    }

    private fun startSimulation(intent: Intent) {
        latitude = intent.getDoubleExtra(EXTRA_LAT, latitude)
        longitude = intent.getDoubleExtra(EXTRA_LNG, longitude)
        accuracyMeters = intent.getDoubleExtra(EXTRA_ACCURACY, accuracyMeters)
        jitterMeters = intent.getDoubleExtra(EXTRA_JITTER, jitterMeters)
        spoofHardening = intent.getBooleanExtra(EXTRA_SPOOF_HARDENING, spoofHardening)
        baseAltitude = intent.getDoubleExtra(EXTRA_ALTITUDE, baseAltitude)

        if (!MockLocationProbe.mockAppSelected(this)) {
            publish(error = ERROR_NOT_MOCK_APP)
            stopSelf()
            return
        }
        if (!MockLocationProbe.fineLocationGranted(this)) {
            publish(error = ERROR_LOCATION_PERMISSION)
            stopSelf()
            return
        }

        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                } else {
                    0
                },
            )
        } catch (e: Exception) {
            publish(error = e.message ?: "Could not start the foreground service.")
            stopSelf()
            return
        }

        try {
            setupProviders()
        } catch (e: SecurityException) {
            publish(error = ERROR_NOT_MOCK_APP)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        } catch (e: Exception) {
            publish(error = e.message ?: "Could not add a test location provider.")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        running = true
        persist()
        publish(error = null)
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    private fun stopSimulation() {
        handler.removeCallbacks(tick)
        tearDownProviders()
        running = false
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_RUNNING, false).apply()
        publish(error = null)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun setupProviders() {
        tearDownProviders()
        val names = linkedSetOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            names += LocationManager.FUSED_PROVIDER
        }
        for (name in names) {
            try {
                try {
                    locationManager.removeTestProvider(name)
                } catch (_: Exception) {
                    // Provider was not a test provider yet.
                }
                locationManager.addTestProvider(
                    name,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    Criteria.POWER_LOW,
                    Criteria.ACCURACY_FINE,
                )
                locationManager.setTestProviderEnabled(name, true)
                enabledProviders += name
            } catch (_: IllegalArgumentException) {
                // OEM already owns this provider name.
            }
        }
        if (enabledProviders.isEmpty()) {
            throw IllegalStateException("No test location providers could be enabled.")
        }
    }

    private fun tearDownProviders() {
        for (name in enabledProviders.toList()) {
            try {
                locationManager.setTestProviderEnabled(name, false)
            } catch (_: Exception) {
            }
            try {
                locationManager.removeTestProvider(name)
            } catch (_: Exception) {
            }
        }
        enabledProviders.clear()
    }

    private fun pushLocation() {
        if (!running) {
            return
        }
        if (!MockLocationProbe.mockAppSelected(this)) {
            publish(error = ERROR_NOT_MOCK_APP)
            stopSimulation()
            return
        }
        val point = jitteredPoint()
        for (name in enabledProviders) {
            try {
                locationManager.setTestProviderLocation(name, buildLocation(name, point.first, point.second))
            } catch (e: Exception) {
                publish(error = e.message ?: "Failed to publish a mock location.")
                stopSimulation()
                return
            }
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
        publish(error = null)
    }

    private fun jitteredPoint(): Pair<Double, Double> {
        if (jitterMeters <= 0.0) {
            return latitude to longitude
        }
        val radius = Random.nextDouble() * jitterMeters
        val angle = Random.nextDouble() * Math.PI * 2
        val dLat = (radius * cos(angle)) / 111_320.0
        val cosLat = cos(Math.toRadians(latitude)).coerceAtLeast(0.000001)
        val dLng = (radius * sin(angle)) / (111_320.0 * cosLat)
        return (latitude + dLat) to (longitude + dLng)
    }

    private fun buildLocation(provider: String, lat: Double, lng: Double): Location {
        val alt = if (spoofHardening) {
            baseAltitude + (Random.nextDouble() * 2.0 - 1.0) // ±1 m natural drift
        } else {
            0.0
        }
        return Location(provider).apply {
            latitude = lat
            longitude = lng
            accuracy = accuracyMeters.toFloat()
            altitude = alt
            bearing = 0f
            speed = 0.1f
            time = System.currentTimeMillis()
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                verticalAccuracyMeters = 3f
                speedAccuracyMetersPerSecond = 0.5f
                bearingAccuracyDegrees = 5f
            }
            if (spoofHardening) {
                SpoofHardening.enrichExtras(this, alt)
                SpoofHardening.clearMockFlag(this)
            }
        }
    }

    private fun persist() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putBoolean(KEY_RUNNING, true)
            .putFloat(KEY_LAT, latitude.toFloat())
            .putFloat(KEY_LNG, longitude.toFloat())
            .putFloat(KEY_ACCURACY, accuracyMeters.toFloat())
            .putFloat(KEY_JITTER, jitterMeters.toFloat())
            .putBoolean(KEY_SPOOF_HARDENING, spoofHardening)
            .putFloat(KEY_ALTITUDE, baseAltitude.toFloat())
            .apply()
    }

    private fun publish(error: String?) {
        SimulationHub.publish(
            MockLocationProbe.statusMap(
                context = this,
                simulating = running,
                latitude = if (running) latitude else null,
                longitude = if (running) longitude else null,
                accuracyMeters = if (running) accuracyMeters else null,
                jitterMeters = if (running) jitterMeters else null,
                spoofHardening = spoofHardening,
                error = error,
            ),
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Location simulation",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while Pinshift is feeding a test location to Android."
            }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val stop =
            PendingIntent.getService(
                this,
                1,
                Intent(this, MockLocationService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val subtitle =
            if (running) {
                String.format("%.5f, %.5f", latitude, longitude)
            } else {
                "Starting…"
            }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Pinshift simulating location")
            .setContentText(subtitle)
            .setOngoing(true)
            .setContentIntent(launch)
            .addAction(0, "Stop", stop)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        const val ACTION_START = "com.pinshift.pinshift.START"
        const val ACTION_STOP = "com.pinshift.pinshift.STOP"
        const val EXTRA_LAT = "lat"
        const val EXTRA_LNG = "lng"
        const val EXTRA_ACCURACY = "accuracy"
        const val EXTRA_JITTER = "jitter"
        const val EXTRA_SPOOF_HARDENING = "spoofHardening"
        const val EXTRA_ALTITUDE = "altitude"
        const val ERROR_NOT_MOCK_APP =
            "Select Pinshift as the mock location app in Developer options."
        const val ERROR_LOCATION_PERMISSION = "Location permission is required to simulate GPS."

        private const val CHANNEL_ID = "pinshift_simulation"
        private const val NOTIFICATION_ID = 41
        private const val TICK_MS = 1000L
        private const val PREFS = "pinshift_sim"
        private const val KEY_RUNNING = "running"
        private const val KEY_LAT = "lat"
        private const val KEY_LNG = "lng"
        private const val KEY_ACCURACY = "accuracy"
        private const val KEY_JITTER = "jitter"
        private const val KEY_SPOOF_HARDENING = "spoof_hardening"
        private const val KEY_ALTITUDE = "altitude"

        fun startIntent(
            context: Context,
            latitude: Double,
            longitude: Double,
            accuracyMeters: Double,
            jitterMeters: Double,
            spoofHardening: Boolean = false,
            altitudeMeters: Double = 0.0,
        ): Intent {
            return Intent(context, MockLocationService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_LAT, latitude)
                putExtra(EXTRA_LNG, longitude)
                putExtra(EXTRA_ACCURACY, accuracyMeters)
                putExtra(EXTRA_JITTER, jitterMeters)
                putExtra(EXTRA_SPOOF_HARDENING, spoofHardening)
                putExtra(EXTRA_ALTITUDE, altitudeMeters)
            }
        }

        fun stopIntent(context: Context): Intent {
            return Intent(context, MockLocationService::class.java).setAction(ACTION_STOP)
        }
    }
}
