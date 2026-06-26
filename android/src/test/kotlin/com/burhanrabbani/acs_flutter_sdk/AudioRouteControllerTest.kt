package com.burhanrabbani.acs_flutter_sdk

import android.content.Context
import android.media.AudioManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Robolectric tests for [AudioRouteController] on the pre-Android-12 path
 * (`@Config(sdk=[30])`), where routing uses `isSpeakerphoneOn`. With no external
 * device connected (Robolectric's default device list is empty), `start()` must
 * force the loudspeaker and set the in-communication mode; `stop()` must restore.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class AudioRouteControllerTest {

    private lateinit var context: Context
    private lateinit var audioManager: AudioManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
        @Suppress("DEPRECATION")
        audioManager.isSpeakerphoneOn = false
    }

    @Test
    fun `start with no external device forces the loudspeaker and in-communication mode`() {
        val controller = AudioRouteController(context)

        controller.start()

        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audioManager.mode)
        @Suppress("DEPRECATION")
        assertTrue(audioManager.isSpeakerphoneOn)
    }

    @Test
    fun `stop restores the previous mode and clears speakerphone`() {
        val controller = AudioRouteController(context)
        controller.start()

        controller.stop()

        assertEquals(AudioManager.MODE_NORMAL, audioManager.mode)
        @Suppress("DEPRECATION")
        assertFalse(audioManager.isSpeakerphoneOn)
    }

    @Test
    fun `start is idempotent (second start does not change the restore baseline)`() {
        val controller = AudioRouteController(context)
        controller.start()
        controller.start() // no-op re-apply; must not capture IN_COMMUNICATION as the baseline
        controller.stop()

        assertEquals(AudioManager.MODE_NORMAL, audioManager.mode)
    }
}
