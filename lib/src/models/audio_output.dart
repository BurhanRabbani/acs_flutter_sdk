/// In-call audio output destinations that can be selected at runtime.
///
/// Used by the dynamic audio-routing API on the calling client. The default
/// while a call is active is [auto], which keeps the built-in loudspeaker unless
/// an external device (Bluetooth / wired / USB / hearing aid) is connected, in
/// which case the external device is used. The other values force a specific
/// destination until the app selects another value or returns to [auto].
enum AudioOutput {
  /// Automatic routing: built-in loudspeaker by default, external device when one
  /// is connected. This is the default in-call behaviour.
  auto,

  /// The built-in loudspeaker (hands-free).
  speaker,

  /// The phone's earpiece / receiver (held-to-ear).
  earpiece,

  /// A connected Bluetooth audio device.
  bluetooth,

  /// A connected wired headset / headphones.
  wiredHeadset,
}

/// Parses an [AudioOutput] from its [AudioOutput.name], returning [AudioOutput.auto]
/// for any unknown or null value so a malformed platform response never throws.
AudioOutput audioOutputFromName(String? name) {
  for (final value in AudioOutput.values) {
    if (value.name == name) return value;
  }
  return AudioOutput.auto;
}
