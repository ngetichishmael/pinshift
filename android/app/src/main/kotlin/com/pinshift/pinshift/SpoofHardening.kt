package com.pinshift.pinshift

import android.location.Location
import android.os.Bundle
import kotlin.random.Random

/**
 * Best-effort suppression of the Android mock-location signals visible to third-party apps.
 *
 * What this can do (no root required):
 *   - Clear isMock / isFromMockProvider via reflection before the Location object is
 *     handed to the system.  On stock AOSP the LocationManagerService re-stamps the flag,
 *     so this is only effective on OEM ROMs that preserve the caller-supplied value.
 *   - Populate extras that real GPS chipsets emit (satellite count, HDOP/VDOP), so apps
 *     that check for missing GPS metadata are less likely to flag the fix as synthetic.
 *   - Vary altitude and GNSS metadata slightly per tick to avoid the constant-value
 *     fingerprint that many mock-detection libraries check.
 *
 * What this CANNOT do without root / Magisk:
 *   - Suppress isMock on stock Android 12+ (system always stamps it after injection).
 *   - Spoof cell-tower or Wi-Fi BSSID location (requires system partition access).
 *   - Change the device's apparent IP/VPN origin (separate concern, unrelated to GPS).
 */
object SpoofHardening {

    /** Attempt to clear both the legacy and API-31+ mock flags via reflection. */
    fun clearMockFlag(location: Location) {
        clearBooleanField(location, "mMock")              // API 31+
        clearBooleanField(location, "mIsFromMockProvider") // pre-31 / some OEMs
    }

    /**
     * Add GPS chipset extras that a real fix would carry.
     * Preserves any existing extras already on the location.
     */
    fun enrichExtras(location: Location, altitudeMeters: Double) {
        val bundle = location.extras?.let { Bundle(it) } ?: Bundle()
        bundle.putInt("satellites", 8 + Random.nextInt(5))          // 8–12 visible SVs
        bundle.putFloat("hdop", 0.8f + Random.nextFloat() * 0.6f)   // 0.8–1.4 (good fix)
        bundle.putFloat("vdop", 1.0f + Random.nextFloat() * 0.8f)   // 1.0–1.8
        bundle.putDouble("altitude", altitudeMeters)                 // consistent with Location.altitude
        location.extras = bundle
    }

    // ── reflection helper ────────────────────────────────────────────────────

    private fun clearBooleanField(target: Any, name: String) {
        try {
            val f = target.javaClass.getDeclaredField(name)
            f.isAccessible = true
            f.setBoolean(target, false)
        } catch (_: Exception) {
            // Field absent on this ROM/API — ignore.
        }
    }
}
