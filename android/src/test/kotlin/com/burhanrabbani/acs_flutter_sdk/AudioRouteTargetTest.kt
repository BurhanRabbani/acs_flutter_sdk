package com.burhanrabbani.acs_flutter_sdk

import android.media.AudioDeviceInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Unit tests for the explicit (app-selected) routing helpers on [AudioRoutePolicy].
 * Pure functions over `AudioDeviceInfo.TYPE_*` ints — no `AudioManager` needed.
 */
class AudioRouteTargetTest {

    @Test
    fun `target name parsing round-trips and defaults to auto`() {
        for (target in AudioRoutePolicy.AudioTarget.values()) {
            val name = AudioRoutePolicy.targetName(target)
            assertEquals(target, AudioRoutePolicy.targetFromName(name))
        }
        assertEquals(AudioRoutePolicy.AudioTarget.AUTO, AudioRoutePolicy.targetFromName(null))
        assertEquals(AudioRoutePolicy.AudioTarget.AUTO, AudioRoutePolicy.targetFromName("mystery"))
    }

    @Test
    fun `dart names match the flutter enum spelling`() {
        assertEquals("auto", AudioRoutePolicy.targetName(AudioRoutePolicy.AudioTarget.AUTO))
        assertEquals("speaker", AudioRoutePolicy.targetName(AudioRoutePolicy.AudioTarget.SPEAKER))
        assertEquals("earpiece", AudioRoutePolicy.targetName(AudioRoutePolicy.AudioTarget.EARPIECE))
        assertEquals("bluetooth", AudioRoutePolicy.targetName(AudioRoutePolicy.AudioTarget.BLUETOOTH))
        assertEquals("wiredHeadset", AudioRoutePolicy.targetName(AudioRoutePolicy.AudioTarget.WIRED))
    }

    @Test
    fun `available targets always offer auto and speaker`() {
        val none = AudioRoutePolicy.availableTargets(emptySet())
        assertEquals(
            listOf(AudioRoutePolicy.AudioTarget.AUTO, AudioRoutePolicy.AudioTarget.SPEAKER),
            none,
        )
    }

    @Test
    fun `available targets include earpiece bluetooth and wired when present`() {
        val connected = setOf(
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
        )
        val targets = AudioRoutePolicy.availableTargets(connected)
        assertEquals(
            listOf(
                AudioRoutePolicy.AudioTarget.AUTO,
                AudioRoutePolicy.AudioTarget.SPEAKER,
                AudioRoutePolicy.AudioTarget.EARPIECE,
                AudioRoutePolicy.AudioTarget.BLUETOOTH,
                AudioRoutePolicy.AudioTarget.WIRED,
            ),
            targets,
        )
    }

    @Test
    fun `built-in targets resolve to their device type regardless of connections`() {
        assertEquals(
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.SPEAKER, emptySet()),
        )
        assertEquals(
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.EARPIECE, emptySet()),
        )
    }

    @Test
    fun `auto resolves to null so caller uses automatic policy`() {
        assertNull(AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.AUTO, emptySet()))
    }

    @Test
    fun `external target resolves to a connected device or null when absent`() {
        val withBt = setOf(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
        assertEquals(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.BLUETOOTH, withBt),
        )
        // No Bluetooth connected → null, signalling a fallback to automatic routing.
        assertNull(
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.BLUETOOTH, emptySet()),
        )

        val withWired = setOf(AudioDeviceInfo.TYPE_USB_HEADSET)
        assertEquals(
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.WIRED, withWired),
        )
        assertNull(
            AudioRoutePolicy.deviceTypeForTarget(AudioRoutePolicy.AudioTarget.WIRED, emptySet()),
        )
    }
}
