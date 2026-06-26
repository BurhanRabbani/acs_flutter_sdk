import AVFoundation
import Flutter
import UIKit
import XCTest


@testable import acs_flutter_sdk

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = AcsFlutterSdkPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}

/// Unit tests for `ParticipantTileContainerRegistry`: the container-only owner of
/// per-participant grid tiles. It holds no renderers (the render manager owns those),
/// so these tests need no ACS SDK or GPU surface; they run on the main thread as the
/// registry requires.
final class ParticipantTileContainerRegistryTests: XCTestCase {

  func testContainerIsStablePerParticipant() {
    let reg = ParticipantTileContainerRegistry()

    let first = reg.container(for: "a")
    let second = reg.container(for: "a")

    XCTAssertTrue(first === second) // same container reused across mounts
    XCTAssertTrue(reg.hasContainer(for: "a"))
  }

  func testEmbedAddsSingleSubview() {
    let reg = ParticipantTileContainerRegistry()
    let container = reg.container(for: "a")
    let video = UIView()

    reg.embed(video, for: "a")

    XCTAssertEqual(container.subviews.count, 1)
    XCTAssertTrue(container.subviews.first === video)
  }

  func testEmbedReplacesPreviousVideoView() {
    let reg = ParticipantTileContainerRegistry()
    let container = reg.container(for: "a")
    let first = UIView()
    let second = UIView()

    reg.embed(first, for: "a")
    reg.embed(second, for: "a")

    XCTAssertEqual(container.subviews.count, 1) // old view swapped out
    XCTAssertTrue(container.subviews.first === second)
  }

  func testClearEmbeddedKeepsContainer() {
    let reg = ParticipantTileContainerRegistry()
    let container = reg.container(for: "a")
    reg.embed(UIView(), for: "a")

    reg.clearEmbedded(for: "a")

    XCTAssertTrue(container.subviews.isEmpty)
    XCTAssertTrue(reg.hasContainer(for: "a")) // container kept for re-embed
  }

  func testRemoveTearsDownContainer() {
    let reg = ParticipantTileContainerRegistry()
    _ = reg.container(for: "a")
    _ = reg.container(for: "b")

    reg.remove("a")

    XCTAssertFalse(reg.hasContainer(for: "a"))
    XCTAssertEqual(reg.mountedParticipantIds(), ["b"])
  }
}

/// Unit tests for `RemoteVideoRenderManager`: the single cached-renderer owner. A
/// fake renderer factory is injected (via the designated initializer) so the cache,
/// lazy-display diff, crash-safe dispose, and first-frame plumbing are exercised
/// without the ACS SDK or a GPU surface. All methods run on the main thread as the
/// manager's `dispatchPrecondition` requires (XCTest runs test bodies on main).
final class RemoteVideoRenderManagerTests: XCTestCase {

  /// Fake handle standing in for the real ACS renderer.
  private final class FakeHandle: ManagedRendererHandle {
    let view = UIView()
    private(set) var disposed = false
    let fire: () -> Void
    init(fire: @escaping () -> Void) { self.fire = fire }
    func dispose() { disposed = true }
  }

  private struct FakeStream: RenderableVideoStream {
    let renderStreamId: Int
  }

  /// Builds a manager whose injected factory records created handles (keyed by stream
  /// id) and counts builds. Returns the manager plus accessors for assertions.
  private func makeManager(
    firstFrames: @escaping (String) -> Void = { _ in }
  ) -> (manager: RemoteVideoRenderManager, buildCount: () -> Int, handle: (Int) -> FakeHandle?) {
    var built: [Int: FakeHandle] = [:]
    var buildCount = 0
    let manager = RemoteVideoRenderManager(
      onFirstFrame: firstFrames,
      makeRenderer: { stream, fire in
        buildCount += 1
        let handle = FakeHandle(fire: fire)
        built[stream.renderStreamId] = handle
        return handle
      }
    )
    return (manager, { buildCount }, { built[$0] })
  }

  func testCacheHitReturnsSameViewAndBuildsOnce() {
    let (manager, buildCount, _) = makeManager()
    let v1 = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    let v2 = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    XCTAssertNotNil(v1)
    XCTAssertTrue(v1 === v2)        // same cached view
    XCTAssertEqual(buildCount(), 1) // renderer built exactly once
  }

  func testDistinctStreamsBuildDistinctRenderers() {
    let (manager, buildCount, _) = makeManager()
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    _ = manager.rendererView(participantId: "b", stream: FakeStream(renderStreamId: 2))
    XCTAssertEqual(buildCount(), 2)
    XCTAssertTrue(manager.isRendering(participantId: "a", streamId: 1))
    XCTAssertTrue(manager.isRendering(participantId: "b", streamId: 2))
  }

  func testUpdateDisplayedDisposesOnlyOffscreen() {
    let (manager, _, handle) = makeManager()
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    _ = manager.rendererView(participantId: "b", stream: FakeStream(renderStreamId: 2))
    manager.updateDisplayed(["a:1"]) // keep a, drop b
    XCTAssertTrue(manager.isRendering(participantId: "a", streamId: 1))
    XCTAssertFalse(manager.isRendering(participantId: "b", streamId: 2))
    XCTAssertEqual(handle(2)?.disposed, true)
    XCTAssertEqual(handle(1)?.disposed, false)
  }

  func testDisposeAllWithMultipleEntriesDoesNotCrash() {
    // Regression for the dict-mutation-during-enumeration crash.
    let (manager, _, _) = makeManager()
    for i in 1...5 {
      _ = manager.rendererView(participantId: "p\(i)", stream: FakeStream(renderStreamId: i))
    }
    manager.disposeAll()
    XCTAssertFalse(manager.isRendering(participantId: "p1", streamId: 1))
    XCTAssertFalse(manager.isRendering(participantId: "p5", streamId: 5))
  }

  func testDisposeParticipantDropsAllItsStreams() {
    let (manager, _, _) = makeManager()
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 2))
    _ = manager.rendererView(participantId: "b", stream: FakeStream(renderStreamId: 3))
    manager.disposeParticipant("a")
    XCTAssertFalse(manager.isRendering(participantId: "a", streamId: 1))
    XCTAssertFalse(manager.isRendering(participantId: "a", streamId: 2))
    XCTAssertTrue(manager.isRendering(participantId: "b", streamId: 3))
  }

  func testFirstFrameForwardsParticipantId() {
    var fired: [String] = []
    let (manager, _, handle) = makeManager(firstFrames: { fired.append($0) })
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    handle(1)?.fire() // simulate the renderer painting its first frame
    XCTAssertEqual(fired, ["a"])
  }

  func testCreateFailureReturnsNilAndDoesNotCache() {
    let manager = RemoteVideoRenderManager(
      onFirstFrame: { _ in },
      makeRenderer: { _, _ in nil } // factory always fails
    )
    let view = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    XCTAssertNil(view)
    // Slot not consumed → a later event / reconcile retry can re-attempt.
    XCTAssertFalse(manager.isRendering(participantId: "a", streamId: 1))
  }

  func testReRequestAfterDisposeBuildsFreshRendererNotAReusedDisposedOne() {
    // Crash-contract: a renderer must NEVER be reused after dispose (touching a disposed
    // ACS renderer is the abort class). After disposing, re-requesting the same stream
    // must build a brand-new handle, and each handle is disposed at most once.
    let (manager, buildCount, handle) = makeManager()
    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    manager.disposeParticipant("a")
    let firstHandle = handle(1)
    XCTAssertEqual(firstHandle?.disposed, true) // the original was disposed exactly once

    _ = manager.rendererView(participantId: "a", stream: FakeStream(renderStreamId: 1))
    XCTAssertEqual(buildCount(), 2)             // a NEW renderer was built…
    XCTAssertEqual(handle(1)?.disposed, false)  // …and it is live, not the reused disposed one
  }

}

/// Unit tests for the pure audio-route policy in `AudioRouteManager`: the call
/// should use the loudspeaker only when NO external output device is present.
final class AudioRouteManagerTests: XCTestCase {

  func testSpeakerWhenNoExternalDevice() {
    XCTAssertTrue(AudioRouteManager.shouldRouteToSpeaker(outputPortTypes: []))
    XCTAssertTrue(AudioRouteManager.shouldRouteToSpeaker(outputPortTypes: [.builtInReceiver]))
    XCTAssertTrue(AudioRouteManager.shouldRouteToSpeaker(outputPortTypes: [.builtInSpeaker]))
  }

  func testNotSpeakerWhenExternalDevicePresent() {
    let external: [AVAudioSession.Port] = [
      .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
      .headphones, .carAudio, .usbAudio, .airPlay,
    ]
    for port in external {
      XCTAssertFalse(
        AudioRouteManager.shouldRouteToSpeaker(outputPortTypes: [port]),
        "expected external port \(port.rawValue) to suppress the speaker override"
      )
    }
  }

  func testExternalWinsWhenMixedWithBuiltIn() {
    XCTAssertFalse(
      AudioRouteManager.shouldRouteToSpeaker(outputPortTypes: [.builtInSpeaker, .bluetoothA2DP])
    )
  }
}
