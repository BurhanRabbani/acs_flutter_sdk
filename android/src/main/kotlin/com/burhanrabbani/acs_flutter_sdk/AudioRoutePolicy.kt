package com.burhanrabbani.acs_flutter_sdk

import android.media.AudioDeviceInfo

/**
 * Pure decision logic for in-call audio output routing, extracted from
 * [AudioRouteController] so it can be unit-tested without an `AudioManager`.
 *
 * Rule: if ANY connected output device is an external device the user explicitly
 * connected (Bluetooth / wired / USB / hearing aid), route to that device
 * ([RouteTarget.EXTERNAL]); otherwise force the built-in loudspeaker
 * ([RouteTarget.SPEAKER]).
 */
object AudioRoutePolicy {

    /** Where in-call audio should go. */
    enum class RouteTarget { EXTERNAL, SPEAKER }

    /**
     * `AudioDeviceInfo.TYPE_*` values that represent an external output device.
     * These are compile-time constants (compileSdk includes them), so referencing
     * the newer ones requires no runtime version guard.
     */
    val externalTypes: Set<Int> = setOf(
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_HEARING_AID,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
    )

    /** True if [type] is an external output device. */
    fun isExternal(type: Int): Boolean = externalTypes.contains(type)

    /**
     * Decides the route from the set of currently-connected output device types:
     * [RouteTarget.EXTERNAL] when any external device is present, else
     * [RouteTarget.SPEAKER] (the built-in loudspeaker).
     */
    fun decide(connectedOutputTypes: Set<Int>): RouteTarget {
        return if (connectedOutputTypes.any { isExternal(it) }) {
            RouteTarget.EXTERNAL
        } else {
            RouteTarget.SPEAKER
        }
    }
}
