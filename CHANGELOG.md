## 0.2.13

Includes everything in 0.2.12 (audio output device names, in-call noise suppression): 0.2.12 was not released to pub.dev; its changes ship in 0.2.13.

* **Fix — diagnostics and media-statistics payloads**. Changes are additive except the two called out below (iOS `lastUpdated` type, iOS diagnostic `name`).
  * **Type change (iOS):** media statistics `report.lastUpdated` is now epoch milliseconds (an integer, as on Android) instead of an ISO-8601 string, which made `MediaStatisticsEvent.timestamp` throw a `TypeError`. `timestamp` now also tolerates numbers, ISO strings and falls back to `data['timestamp']`; it never throws.
  * Diagnostics change events now also carry `diagnostic` (same as `name`), `isFlagDiagnostic`, `valueBool` (flag events) and a lower-case `valueQuality` (quality events), so the `DiagnosticsEvent` getters return real values. Existing `name`/`value` keys stay (see the iOS `name` note below). The getters are tolerant of missing or wrongly typed fields (`valueBool` on a non-bool now returns `null` instead of throwing).
  * Diagnostics snapshots (`diagnosticsSnapshot`, `getLatestDiagnostics`) carry both `isCameraFrozen` and the legacy `isCameraFreeze` on Android and iOS (iOS previously had only `isCameraFreeze`).
  * The current diagnostics are now delivered when a listener attaches to the diagnostics stream, as one change event per known diagnostic (unknown flags and `unknown` qualities skipped). Previously the attach-time snapshot was dropped and a stable call emitted nothing.
  * **iOS `name` may change:** diagnostic `name` values are now fixed literals identical to Android's (for example `isCameraFrozen`) instead of the string the SDK supplied. Consumers on iOS that matched the previous SDK-supplied `name` should re-check; `diagnostic` carries the same literal.
  * Documented units (bitrate in bps, jitter and freeze durations in ms, `packetsLostPerSecond` is a rate), that incoming audio statistics have no participant identifier, and that raw quality values keep each platform's casing (Android upper-case, iOS lower-case) while `valueQuality` is always lower-case. Live iOS quality events keep their previous `value` form, whereas replayed events send a lower-case `value`; use `valueQuality` for a stable lower-case form.

## 0.2.12

* **Feature — change noise suppression during a call**: new `AcsCallClient.setNoiseSuppressionMode(String mode)` and `getNoiseSuppressionMode()` adjust the outgoing-audio noise suppression of the active call (`off`, `auto`, `low`, `high`, the same values `joinTeamsMeeting(noiseSuppressionMode:)` accepts). They use the SDK's live outgoing audio filters on Android and iOS, and change only noise suppression (echo cancellation and music mode are untouched). The setter is stricter than the join-time option (which ignores unknown values): an unknown or empty mode fails the returned future with `ArgumentError`. Without an active call both throw `AcsCallingException` with code `NO_ACTIVE_CALL`; on Android, changing the mode before the call is connected may fail with `NOISE_SUPPRESSION_FAILED`. The setting applies to the current call only and is not persisted; `getNoiseSuppressionMode()` returns `null` when the mode is unknown or unavailable.
* **Feature — audio output device names**: new `AcsCallClient.getAvailableAudioOutputDevices()` returns `List<AudioOutputDevice>` (`type` plus the OS-reported `name`, e.g. "AirPods Pro"), so apps can label an output picker. It is additive: `getAvailableAudioOutputs()` and `setAudioRoute()` are unchanged, and the device list's types normally match `getAvailableAudioOutputs()` for the same device state (each call is its own snapshot). Names come from `AudioDeviceInfo.productName` on Android and `AVAudioSessionPortDescription.portName` on iOS; `auto` and outputs the platform does not name have a `null` name.

## 0.2.11

* **Feature — dynamic audio-output API**: the calling client can now switch the in-call audio output at runtime via `setAudioRoute(AudioOutput target)`, read the current output with `getAudioRoute()`, and list selectable outputs with `getAvailableAudioOutputs()`. The new `AudioOutput` enum covers `auto`, `speaker`, `earpiece`, `bluetooth`, and `wiredHeadset`. `auto` (the default) keeps the existing behaviour — built-in loudspeaker, switching to a connected external device — while an explicit value is honoured until changed or reset to `auto`; if a selected external device disconnects, routing reverts to automatic. Implemented natively on Android (`AudioManager`) and iOS (`AVAudioSession`) with unit-tested routing logic.

## 0.2.10

* **Fix — release renderers before detaching the call channel**: when a call screen closes, the SDK now asks the native side to tear down every video renderer and release the render manager *before* the method-call handler is detached, dispatched while the channel is still live. This prevents leaked renderers / a teardown crash when leaving a multi-participant call.
* **Feature — in-call audio output routing**: in-call audio is now routed to the device's built-in loudspeaker by default, and automatically to an external output device (Bluetooth, wired headset/headphones, USB, or hearing aid) whenever one is connected. Implemented natively on both Android and iOS with unit-tested routing logic.

## 0.2.9

* **iOS — fix video-call freeze on iOS 26**: Remote video renderer teardown no longer blocks the platform/UI thread. The view is detached synchronously while the underlying renderer's decoder-session disposal is deferred to the next main-runloop turn, so it no longer re-enters the in-flight platform-view dispose handshake. This removes a main-thread stall that froze the app on any action during a multi-participant call on iOS 26 (reproduced on both simulator and device) and stopped the associated memory growth from undisposed decoder sessions. iOS 18 was unaffected by the original behaviour. The renderer teardown stays on the main thread, preserving the SDK's main-thread renderer affinity.

## 0.2.8

* **Screen sharing**: Render incoming screen-share streams in the participant grid, with dedicated handling so a shared screen and camera feeds display together.
* **Multi-participant video stability**: Reworked remote video rendering to track each participant's renderer independently, preventing frozen or blank tiles when participants join, leave, or toggle their camera.
* **iOS**: Added a native exception guard around local video stream creation so the app fails gracefully instead of crashing when camera hardware is briefly unavailable.
* **Android**: Hardened the screen-share capture lifecycle handling.
* **Calling API**: Consolidated call state and event models for clearer, type-safe call handling.
* **Cleanup**: Removed the deprecated chat module and its tests (chat was retired in 0.2.3); package description and topics updated accordingly.
* **Tooling**: Upgraded to `flutter_lints` 6.0.0; static analysis passes with no issues.

## 0.2.7

* **Critical Bug Fix**: Prevent crash when ACS SDK throws NSException during `LocalVideoStream` initialization
* iOS: Add Objective-C exception catcher to safely handle `ACSLocalVideoStream init:` failures
* Android: Add try-catch around `LocalVideoStream` constructor for defensive error handling
* Gracefully returns error to Flutter instead of crashing the app
* Addresses crash on iOS 18.6+ when camera hardware is temporarily unavailable

## 0.2.6

* **Critical Bug Fix**: Fixed NullPointerException crash in media statistics serialization on both platforms
* **Android**: Fixed null-safety in `serializeOutgoingStatistics()` and `serializeIncomingStatistics()` methods
* **iOS**: Fixed null-safety in `serialize(outgoingStatistics:)` and `serialize(incomingStatistics:)` methods
* **Impact**: Prevents app crashes when joining calls with video/mic disabled or during initial connection phase
* **Details**: Added null checks to gracefully handle race condition when media statistics collection starts before streams are established
* **README**: Updated to document chat module removal (removed in v0.2.3 for app size optimization)

## 0.2.5

* **Bug Fix**: Prevent crash when camera permission is denied during video call initialization
* iOS: Add `AVCaptureDevice.authorizationStatus` check before creating `LocalVideoStream`
* Android: Add `ContextCompat.checkSelfPermission` check before creating `LocalVideoStream`
* Gracefully handle denied camera permissions instead of crashing the app

## 0.2.4

* Updated README.md with accurate documentation
* Fixed broken documentation links
* Updated Chat section with deprecation notice
* Fixed analyzer warnings in example app
* Improved dartdoc comments

## 0.2.3

* **BREAKING**: Chat SDK removed to reduce app size - `createChatClient()` now throws `UnsupportedError`
* For chat functionality, use UI Library ChatComposite or implement server-side chat
* Documentation update for UI Library features
* Updated README.md with comprehensive UI Library documentation
* Added comparison table between Custom UI and UI Library approaches
* Added UI Library usage examples (group calls, Teams meetings)
* Reorganized README structure to distinguish between two SDK approaches
* Updated architecture diagram to show both AcsFlutterSdk and AcsUiLibrary
* Added Documentation section with links to implementation guide

## 0.2.2

* Add Azure Communication Services UI Library support
* New AcsUiLibrary class for pre-built CallComposite and ChatComposite components
* Add native Android UI Library plugin (AcsUiLibraryPlugin.kt)
* Add native iOS UI Library plugin (AcsUiLibraryPlugin.swift)
* Support for Group Calls, Teams Meetings, Rooms, and 1:1 calls via UI composites
* Add localization support for 20+ languages in UI Library
* Add theming and multitasking (Picture-in-Picture) options
* Comprehensive UI Library implementation documentation
* Fix deprecated Color.value usage (now uses toARGB32)
* Remove unnecessary dart:typed_data import

## 0.1.3

* Fix Android compilation errors for Azure Chat SDK 2.0.3 API compatibility
* Update Android plugin to use correct Azure SDK method signatures
* Fix manifest merger conflicts and resource packaging issues
* Resolve Kotlin compilation errors in calling and chat modules

## 0.1.2

* Add `joinTeamsMeeting` APIs on Dart, Android, and iOS bridges
* Wire the example app with manual group call / Teams meeting join flows
* Document initialization requirements and Teams meeting limitations
* Extend unit tests to cover the new meeting-link workflow

## 0.1.1

* Fix platform channel payload mismatches for calling and chat responses
* Require chat endpoint during initialization and harden message parsing
* Update Android/iOS plugin package metadata and example app permissions
* Refresh documentation to clarify identity requirements and remove unsupported features
* Prepare build scripts and podspec for publishing under the new namespace
* Add Android video support (local preview, remote rendering, camera switching) and runtime permission helper

## 0.1.0

* Initial release of Azure Communication Services Flutter SDK
* ✅ Identity management support (create users, manage tokens)
* ✅ Voice and video calling capabilities
* ✅ Chat functionality with real-time messaging
* ✅ Android support (API 24+)
* ✅ iOS support (iOS 13.0+)
* ✅ Comprehensive documentation and examples
* ✅ Sound null safety support
* 📦 Uses Azure Communication Services SDK versions:
  * Android: Calling 2.15.0, Chat 2.0.3, Common 1.2.1
  * iOS: Calling 2.15.1, Chat 1.3.6, Common 1.3.0
