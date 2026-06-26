package com.burhanrabbani.acs_flutter_sdk

import android.content.Context
import android.view.View
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
 * Unit tests for [ParticipantVideoRegistry]'s slot bookkeeping: the per-participant
 * renderer model, the 9-renderer cap, and the FIFO backfill that promotes a queued
 * participant when a slot frees. This is the exact logic behind the multi-remote
 * black-screen fix, exercised here with a fake [RendererFactory] so no native ACS
 * renderer (or GPU/GL surface) is required — Robolectric supplies real FrameLayout
 * containers and a main Looper on the JVM.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ParticipantVideoRegistryTest {

    private lateinit var context: Context

    /** Number of live (non-disposed) fake renderers the factory has handed out. */
    private var liveRenderers = 0

    /**
     * Fake factory: returns a plain [View] handle (no ACS renderer) and tracks
     * dispose calls so tests can assert slots are genuinely freed. Parameterised on
     * [String] streams so no final ACS class needs mocking.
     */
    private val fakeFactory = RendererFactory<String> { _, ctx ->
        liveRenderers++
        RendererHandle(View(ctx)) { liveRenderers-- }
    }

    /** A factory that always fails to build a renderer (returns null). */
    private val failingFactory = RendererFactory<String> { _, _ -> null }

    /**
     * True if ANY renderer's `dispose()` ran while its view was already detached from
     * its parent (`view.parent == null`). That is the exact precondition for the native
     * ACS crash: `RemoteIncomingVideoStreamRenderer.StopPreview()` dereferences the
     * view's (now-null) `TextureView` and aborts. The registry MUST dispose the renderer
     * BEFORE removing its view, so this must stay false.
     */
    private var disposedWhileDetached = false

    /** How many times any renderer's `dispose()` ran — to catch double-dispose. */
    private var disposeCount = 0

    /**
     * Crash-contract factory: a fake whose `dispose()` mimics ACS `StopPreview()` by
     * touching the view. It records [disposedWhileDetached] if the view was already
     * removed from its container at dispose time (the abort precondition). Encoding the
     * precondition here turns the untestable native SIGABRT into a JVM assertion: the
     * buggy `removeAllViews()`-then-`dispose()` order sets the flag; the fixed order
     * (`dispose()`-then-`removeAllViews()`) leaves it false.
     */
    private val crashContractFactory = RendererFactory<String> { _, ctx ->
        val view = View(ctx)
        liveRenderers++
        RendererHandle(view) {
            disposeCount++
            if (view.parent == null) disposedWhileDetached = true
            liveRenderers--
        }
    }

    private fun newRegistry(factory: RendererFactory<String> = fakeFactory) =
        ParticipantVideoRegistry(context, factory)

    /** Distinct trivial stream token per call; content is irrelevant to the fake factory. */
    private fun stream(): String = "stream-${streamCounter++}"

    private var streamCounter = 0

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        liveRenderers = 0
        disposedWhileDetached = false
        disposeCount = 0
    }

    @Test
    fun `attach renders into a mounted tile`() {
        val reg = newRegistry()
        reg.containerForParticipant("a")

        reg.attach("a", stream())

        assertTrue(reg.isRendering("a"))
        assertEquals(1, liveRenderers)
    }

    @Test
    fun `attach without a container is a no-op`() {
        val reg = newRegistry()

        reg.attach("ghost", stream())

        assertFalse(reg.hasContainer("ghost"))
        assertFalse(reg.isRendering("ghost"))
        assertEquals(0, liveRenderers)
    }

    @Test
    fun `attach is idempotent for an already-rendering tile`() {
        val reg = newRegistry()
        reg.containerForParticipant("a")

        reg.attach("a", stream())
        reg.attach("a", stream())

        assertTrue(reg.isRendering("a"))
        assertEquals(1, liveRenderers) // second attach created no extra renderer
    }

    @Test
    fun `factory failure leaves the slot free for retry`() {
        val reg = newRegistry(failingFactory)
        reg.containerForParticipant("a")

        reg.attach("a", stream())

        assertFalse(reg.isRendering("a")) // null handle → not consumed
    }

    @Test
    fun `caps active renderers at nine and queues the tenth`() {
        val reg = newRegistry()
        val ids = (1..10).map { "p$it" }
        ids.forEach { reg.containerForParticipant(it) }

        ids.forEach { reg.attach(it, stream()) }

        assertEquals(9, liveRenderers)
        assertEquals(9, ids.count { reg.isRendering(it) })
        assertFalse(reg.isRendering("p10")) // queued, not rendering
    }

    @Test
    fun `detach frees a slot and backfills the oldest queued waiter (FIFO)`() {
        val reg = newRegistry()
        val ids = (1..11).map { "p$it" }
        ids.forEach { reg.containerForParticipant(it) }
        ids.forEach { reg.attach(it, stream()) }
        // p10, p11 are queued in arrival order; p1..p9 render.
        assertFalse(reg.isRendering("p10"))
        assertFalse(reg.isRendering("p11"))

        reg.detach("p1")

        assertFalse(reg.isRendering("p1"))
        assertTrue(reg.isRendering("p10")) // oldest waiter promoted first
        assertFalse(reg.isRendering("p11"))
        assertEquals(9, liveRenderers) // still capped at nine
    }

    @Test
    fun `dispose of a rendering tile frees a slot and backfills`() {
        val reg = newRegistry()
        val ids = (1..10).map { "p$it" }
        ids.forEach { reg.containerForParticipant(it) }
        ids.forEach { reg.attach(it, stream()) }
        assertFalse(reg.isRendering("p10"))

        reg.dispose("p1")

        assertFalse(reg.hasContainer("p1"))
        assertTrue(reg.isRendering("p10")) // backfilled
        assertEquals(9, liveRenderers)
    }

    @Test
    fun `a waiter disposed while queued is skipped on backfill`() {
        val reg = newRegistry()
        val ids = (1..11).map { "p$it" }
        ids.forEach { reg.containerForParticipant(it) }
        ids.forEach { reg.attach(it, stream()) }
        // p10 (oldest waiter) and p11 queued.

        reg.dispose("p10") // remove the oldest waiter before any slot frees
        reg.detach("p1")   // frees a slot → backfill should skip p10, promote p11

        assertFalse(reg.hasContainer("p10"))
        assertTrue(reg.isRendering("p11"))
        assertEquals(9, liveRenderers)
    }

    @Test
    fun `detach without queued waiters simply frees the slot`() {
        val reg = newRegistry()
        reg.containerForParticipant("a")
        reg.attach("a", stream())
        assertEquals(1, liveRenderers)

        reg.detach("a")

        assertFalse(reg.isRendering("a"))
        assertTrue(reg.hasContainer("a")) // container kept for re-attach
        assertEquals(0, liveRenderers)
    }

    @Test
    fun `clear tears down every renderer and tile`() {
        val reg = newRegistry()
        val ids = (1..5).map { "p$it" }
        ids.forEach { reg.containerForParticipant(it); reg.attach(it, stream()) }
        assertEquals(5, liveRenderers)

        reg.clear()

        assertEquals(0, liveRenderers)
        assertTrue(reg.mountedParticipantIds().isEmpty())
    }

    // --- Renderer-lifecycle crash contract -------------------------------------
    // These guard the native ACS abort class: disposing a renderer AFTER its view has
    // been detached makes ACS StopPreview() dereference a null TextureView and crash.
    // The crashContractFactory records that precondition so a regression of the
    // dispose-before-detach ordering turns these tests red instead of the device.

    @Test
    fun `detach disposes the renderer before removing its view`() {
        val reg = newRegistry(crashContractFactory)
        reg.containerForParticipant("a")
        reg.attach("a", stream())

        reg.detach("a")

        assertFalse("renderer disposed after its view was detached", disposedWhileDetached)
        assertEquals(1, disposeCount)
    }

    @Test
    fun `dispose(participant) disposes the renderer before removing its view`() {
        val reg = newRegistry(crashContractFactory)
        reg.containerForParticipant("a")
        reg.attach("a", stream())

        reg.dispose("a")

        assertFalse("renderer disposed after its view was detached", disposedWhileDetached)
        assertEquals(1, disposeCount)
    }

    @Test
    fun `clear disposes each renderer before removing its view`() {
        val reg = newRegistry(crashContractFactory)
        (1..3).forEach { reg.containerForParticipant("p$it"); reg.attach("p$it", stream()) }

        reg.clear()

        assertFalse("renderer disposed after its view was detached", disposedWhileDetached)
        assertEquals(3, disposeCount)
    }

    @Test
    fun `camera-on-during-screenshare churn never disposes a detached view`() {
        // Reproduces the crash scenario: a screen participant + a camera participant,
        // with the camera tile flipping availability (detach/re-attach) repeatedly while
        // the share is active. The ordering invariant must hold across all of it.
        val reg = newRegistry(crashContractFactory)
        reg.containerForParticipant("screen")
        reg.containerForParticipant("camera")
        reg.attach("screen", stream())

        repeat(5) {
            reg.attach("camera", stream())   // camera turns on
            reg.detach("camera")             // camera turns off / stream flips unavailable
        }

        assertFalse("renderer disposed after its view was detached", disposedWhileDetached)
        // Cap is never exceeded and the screen renderer survives the churn.
        assertTrue(reg.isRendering("screen"))
        assertFalse(reg.isRendering("camera"))
    }

    @Test
    fun `re-attaching after detach is a fresh render, not a disposed-renderer reuse`() {
        val reg = newRegistry(crashContractFactory)
        reg.containerForParticipant("a")
        reg.attach("a", stream())
        reg.detach("a")
        val disposesAfterFirst = disposeCount

        reg.attach("a", stream()) // camera back on → must build a NEW renderer

        assertTrue(reg.isRendering("a"))
        assertEquals(disposesAfterFirst, disposeCount) // the new renderer is not disposed
        assertFalse(disposedWhileDetached)
    }
}
