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
 * devices is the quiet EARPIECE. This controller enforces the desired route for
 * the life of a call.
 *
 * Two modes:
 *  - AUTO (default): no external device -> built-in LOUDSPEAKER; an external device
 *    connected (Bluetooth / wired / USB / hearing aid) -> use that device.
 *  - MANUAL: the app picked an explicit target via [setRoute]; it is honoured until
 *    the app changes it, selects AUTO, or the picked external device disconnects (in
 *    which case routing reverts to AUTO).
 *
 * It re-evaluates whenever a device is added/removed (via [AudioDeviceCallback]).
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

    /** App-selected output; [AudioRoutePolicy.AudioTarget.AUTO] means automatic policy. */
    private var manualTarget = AudioRoutePolicy.AudioTarget.AUTO

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
            manualTarget = AudioRoutePolicy.AudioTarget.AUTO

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
     * Selects an explicit output by its Dart [AudioRoutePolicy] target name
     * (`auto` / `speaker` / `earpiece` / `bluetooth` / `wiredHeadset`). `auto`
     * resumes automatic routing. Re-applies immediately.
     */
    fun setRoute(targetName: String?) {
        runOnMain {
            manualTarget = AudioRoutePolicy.targetFromName(targetName)
            applyPreferredRoute()
        }
    }

    /** The Dart target name of the output currently in effect. */
    fun currentRoute(): String {
        val connected = connectedOutputTypes()
        val type = resolveDesiredType(connected, mutateOnFallback = false)
        return AudioRoutePolicy.targetName(targetForType(type))
    }

    /** The Dart target names selectable right now, given connected devices. */
    fun availableRoutes(): List<String> =
        AudioRoutePolicy.availableTargets(connectedOutputTypes())
            .map { AudioRoutePolicy.targetName(it) }

    /**
     * The selectable outputs with their OS-reported names, as maps of
     * `{type: <Dart target name>, name: <String?>}`.
     *
     * Invariant: the `type` values and their order equal [availableRoutes] for the
     * same device state, because both come from [AudioRoutePolicy.availableTargets].
     * `auto` has no name. For the others the name is `AudioDeviceInfo.productName`
     * of the first connected output of that kind (blank -> null); built-in outputs
     * report a generic name (often the phone model) that the app may ignore.
     */
    fun availableRouteDevices(): List<Map<String, String?>> {
        val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return AudioRoutePolicy.availableTargets(outputs.map { it.type }.toSet()).map { target ->
            val name = if (target == AudioRoutePolicy.AudioTarget.AUTO) {
                null
            } else {
                // Match the concrete built-in speaker type: targetForType folds every
                // unrecognised type (HDMI, telephony...) into SPEAKER.
                outputs.firstOrNull {
                    if (target == AudioRoutePolicy.AudioTarget.SPEAKER) {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    } else {
                        targetForType(it.type) == target
                    }
                }
                    ?.productName?.toString()?.takeIf { it.isNotBlank() }
            }
            mapOf("type" to AudioRoutePolicy.targetName(target), "name" to name)
        }
    }

    /**
     * Applies the effective output route: the manual override when set and still
     * applicable, otherwise the automatic policy. Safe to call repeatedly.
     */
    private fun applyPreferredRoute() {
        if (!isActive) return
        try {
            val desiredType = resolveDesiredType(connectedOutputTypes(), mutateOnFallback = true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applyRouteApi31(desiredType)
            } else {
                applyRouteLegacy(desiredType)
            }
        } catch (e: Exception) {
            Log.e(TAG, "[AudioRoute] applyPreferredRoute failed", e)
        }
    }

    /**
     * Concrete `AudioDeviceInfo.TYPE_*` to route to. Honours [manualTarget] when it
     * resolves to a present device; otherwise (AUTO, or a vanished external target)
     * uses the automatic policy. When [mutateOnFallback] is true and a manual
     * external target is no longer present, the override is cleared back to AUTO.
     */
    private fun resolveDesiredType(connected: Set<Int>, mutateOnFallback: Boolean): Int {
        if (manualTarget != AudioRoutePolicy.AudioTarget.AUTO) {
            val explicit = AudioRoutePolicy.deviceTypeForTarget(manualTarget, connected)
            if (explicit != null) return explicit
            if (mutateOnFallback) manualTarget = AudioRoutePolicy.AudioTarget.AUTO
        }
        return if (AudioRoutePolicy.decide(connected) == AudioRoutePolicy.RouteTarget.EXTERNAL) {
            connected.firstOrNull { AudioRoutePolicy.isExternal(it) }
                ?: AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        } else {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        }
    }

    /** Android 12+ path: select the communication device matching [desiredType]. */
    private fun applyRouteApi31(desiredType: Int) {
        val devices = audioManager.availableCommunicationDevices
        val target = devices.firstOrNull { it.type == desiredType }
            ?: devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (target != null) {
            val ok = audioManager.setCommunicationDevice(target)
            Log.d(TAG, "[AudioRoute] setCommunicationDevice type=${target.type} desired=$desiredType ok=$ok")
        } else {
            Log.w(TAG, "[AudioRoute] no communication device available to select")
        }
    }

    /** Pre-Android-12 fallback using speakerphone / Bluetooth SCO for [desiredType]. */
    @Suppress("DEPRECATION")
    private fun applyRouteLegacy(desiredType: Int) {
        when {
            desiredType in AudioRoutePolicy.bluetoothTypes -> {
                audioManager.isSpeakerphoneOn = false
                if (!audioManager.isBluetoothScoOn) audioManager.startBluetoothSco()
            }
            desiredType in AudioRoutePolicy.wiredTypes -> {
                if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                audioManager.isSpeakerphoneOn = false
            }
            desiredType == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> {
                if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                audioManager.isSpeakerphoneOn = false
            }
            else -> {
                // Built-in loudspeaker.
                if (audioManager.isBluetoothScoOn) audioManager.stopBluetoothSco()
                audioManager.isSpeakerphoneOn = true
            }
        }
        Log.d(TAG, "[AudioRoute] legacy route desired=$desiredType speaker=${audioManager.isSpeakerphoneOn}")
    }

    /** Output device types currently connected. */
    private fun connectedOutputTypes(): Set<Int> =
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toSet()

    /** Maps a concrete device type back to its [AudioRoutePolicy.AudioTarget]. */
    private fun targetForType(type: Int): AudioRoutePolicy.AudioTarget = when {
        type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> AudioRoutePolicy.AudioTarget.EARPIECE
        type in AudioRoutePolicy.bluetoothTypes -> AudioRoutePolicy.AudioTarget.BLUETOOTH
        type in AudioRoutePolicy.wiredTypes -> AudioRoutePolicy.AudioTarget.WIRED
        else -> AudioRoutePolicy.AudioTarget.SPEAKER
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else mainHandler.post(action)
    }

    private companion object {
        private const val TAG = "ACS"
    }
}
