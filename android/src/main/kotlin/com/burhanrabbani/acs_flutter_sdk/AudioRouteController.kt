package com.burhanrabbani.acs_flutter_sdk

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Drives the call's audio OUTPUT route on Android.
 *
 * Why this exists: ACS uses the system default for in-call audio, which on many
 * devices is the quiet EARPIECE. This controller enforces the desired policy for
 * the life of a call:
 *
 *  - No external device connected -> route to the built-in LOUDSPEAKER.
 *  - An external device IS connected (Bluetooth / wired / USB / hearing aid) ->
 *    use that device, never force the speaker.
 *
 * It re-evaluates whenever a device is added/removed (via [AudioDeviceCallback]),
 * so plugging in a headset switches to it and unplugging reverts to the speaker
 * mid-call.
 *
 * Lifecycle: [start] on call-connected, [stop] on call-disconnected. All work is
 * posted to the main thread. Uses the modern `setCommunicationDevice` API on
 * Android 12 (API 31)+ and falls back to `isSpeakerphoneOn` / Bluetooth SCO on
 * older releases.
 */
class AudioRouteController(context: Context) {

    private val audioManager =
        context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())

    /** True while a call is active and the route is being managed. */
    private var isActive = false

    /** Saved so [stop] can restore the pre-call audio mode. */
    private var previousMode = AudioManager.MODE_NORMAL

    /** Registered while active so device connect/disconnect re-routes the call. */
    private var deviceCallback: AudioDeviceCallback? = null

    /** Begins managing the call audio route and observes device changes. */
    fun start() {
        runOnMain {
            if (isActive) {
                applyPreferredRoute()
                return@runOnMain
            }
            isActive = true
            previousMode = audioManager.mode
            // MODE_IN_COMMUNICATION is required for in-call routing (speakerphone /
            // communication-device selection) to behave correctly.
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

            val callback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) = applyPreferredRoute()
                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) = applyPreferredRoute()
            }
            deviceCallback = callback
            audioManager.registerAudioDeviceCallback(callback, mainHandler)

            applyPreferredRoute()
        }
    }

    /** Stops managing the route and restores the pre-call audio state. */
    fun stop() {
        runOnMain {
            if (!isActive) return@runOnMain
            isActive = false

            deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
            deviceCallback = null

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audioManager.clearCommunicationDevice()
                } else {
                    @Suppress("DEPRECATION")
                    if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                }
            } catch (e: Exception) {
                Log.e(TAG, "[AudioRoute] stop cleanup failed", e)
            }
            audioManager.mode = previousMode
        }
    }

    /**
     * Applies the preferred output route: an external device when one is connected,
     * otherwise the built-in loudspeaker. Safe to call repeatedly.
     */
    private fun applyPreferredRoute() {
        if (!isActive) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applyRouteApi31()
            } else {
                applyRouteLegacy()
            }
        } catch (e: Exception) {
            Log.e(TAG, "[AudioRoute] applyPreferredRoute failed", e)
        }
    }

    /** Android 12+ path using the explicit communication-device API. */
    private fun applyRouteApi31() {
        val devices = audioManager.availableCommunicationDevices
        // Prefer a connected external device; otherwise the built-in speaker.
        val external = devices.firstOrNull { AudioRoutePolicy.isExternal(it.type) }
        val target = external ?: devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (target != null) {
            val ok = audioManager.setCommunicationDevice(target)
            Log.d(TAG, "[AudioRoute] setCommunicationDevice type=${target.type} external=${external != null} ok=$ok")
        } else {
            Log.w(TAG, "[AudioRoute] no communication device available to select")
        }
    }

    /** Pre-Android-12 fallback using speakerphone / Bluetooth SCO. */
    @Suppress("DEPRECATION")
    private fun applyRouteLegacy() {
        val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val hasBluetooth = outputs.any {
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
        }
        val hasWiredOrUsb = outputs.any {
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_USB_DEVICE
        }
        when {
            hasBluetooth -> {
                // Route call audio over the Bluetooth headset (SCO for the call path).
                audioManager.isSpeakerphoneOn = false
                if (!audioManager.isBluetoothScoOn) audioManager.startBluetoothSco()
            }
            hasWiredOrUsb -> {
                // Wired/USB takes priority automatically; just ensure speaker is off.
                if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                audioManager.isSpeakerphoneOn = false
            }
            else -> {
                // No external device → force the main loudspeaker.
                if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                audioManager.isSpeakerphoneOn = true
            }
        }
        Log.d(TAG, "[AudioRoute] legacy route bt=$hasBluetooth wired=$hasWiredOrUsb speaker=${audioManager.isSpeakerphoneOn}")
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else mainHandler.post(action)
    }

    private companion object {
        private const val TAG = "ACS"
    }
}
