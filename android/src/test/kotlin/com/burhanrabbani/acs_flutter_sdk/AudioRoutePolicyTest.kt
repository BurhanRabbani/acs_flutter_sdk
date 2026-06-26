package com.burhanrabbani.acs_flutter_sdk

import android.media.AudioDeviceInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [AudioRoutePolicy]: the pure in-call output-routing decision.
 * No `AudioManager` (and therefore no Robolectric) is required — the policy works
 * on plain `AudioDeviceInfo.TYPE_*` int constants.
 */
class AudioRoutePolicyTest {

    @Test
    fun `no devices routes to speaker`() {
        assertEquals(AudioRoutePolicy.RouteTarget.SPEAKER, AudioRoutePolicy.decide(emptySet()))
    }

    @Test
    fun `built-in only routes to speaker`() {
        val builtins = setOf(
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
        )
        assertEquals(AudioRoutePolicy.RouteTarget.SPEAKER, AudioRoutePolicy.decide(builtins))
    }

    @Test
    fun `each external device type routes to external`() {
        val externals = listOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_HEARING_AID,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
        )
        for (type in externals) {
            assertTrue("type $type should be external", AudioRoutePolicy.isExternal(type))
            assertEquals(
                "type $type should route EXTERNAL",
                AudioRoutePolicy.RouteTarget.EXTERNAL,
                AudioRoutePolicy.decide(setOf(type)),
            )
        }
    }

    @Test
    fun `external wins when mixed with built-in`() {
        val mixed = setOf(
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        )
        assertEquals(AudioRoutePolicy.RouteTarget.EXTERNAL, AudioRoutePolicy.decide(mixed))
    }

    @Test
    fun `built-in speaker and earpiece are not external`() {
        assertFalse(AudioRoutePolicy.isExternal(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER))
        assertFalse(AudioRoutePolicy.isExternal(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE))
    }
}
