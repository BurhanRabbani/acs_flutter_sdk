import 'dart:typed_data';

/// Event emitted by call feature streams.
///
/// Common event types include:
/// - `recordingStateChanged`: Recording started/stopped
/// - `transcriptionStateChanged`: Transcription started/stopped
/// - `dominantSpeakersChanged`: Active speakers changed
/// - `raiseHandChanged`: Hand raise state changed
/// - `spotlightChanged`: Spotlight state changed
class CallFeatureEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const CallFeatureEvent({required this.type, required this.data});

  factory CallFeatureEvent.fromMap(Map<String, dynamic> map) {
    return CallFeatureEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// Whether the feature is active (for recording, transcription events)
  bool? get isActive => data['isActive'] as bool?;

  /// List of dominant speaker identifiers
  List<String> get speakers =>
      (data['speakers'] as List<dynamic>?)?.cast<String>() ?? const [];

  /// List of raised hand entries (for raiseHandChanged events)
  List<RaisedHandInfo> get raisedHands {
    final list = data['raisedHands'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .map((e) => RaisedHandInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// List of spotlighted participant identifiers (for spotlightChanged events)
  List<String> get spotlightedParticipants =>
      (data['spotlightedParticipants'] as List<dynamic>?)?.cast<String>() ??
      const [];
}

/// Event emitted when captions state or text updates arrive.
///
/// Common event types include:
/// - `captionsActiveChanged`: Captions enabled/disabled
/// - `captionsReceived`: Caption text received
/// - `spokenLanguageChanged`: Spoken language changed
/// - `captionLanguageChanged`: Caption language changed
class CaptionsEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const CaptionsEvent({required this.type, required this.data});

  factory CaptionsEvent.fromMap(Map<String, dynamic> map) {
    return CaptionsEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// Whether captions are currently active
  bool? get isActive => data['isActive'] as bool?;

  /// The spoken text (original language)
  String? get spokenText => data['spokenText'] as String?;

  /// The caption text (translated if applicable)
  String? get captionText => data['captionText'] as String?;

  /// The speaker identifier
  String? get speakerRawId => data['speakerRawId'] as String?;

  /// The speaker's display name
  String? get speakerName => data['speakerName'] as String?;

  /// The spoken language code (e.g., 'en-US')
  String? get spokenLanguage => data['spokenLanguage'] as String?;

  /// The caption language code (e.g., 'es')
  String? get captionLanguage => data['captionLanguage'] as String?;

  /// Caption result type: 'partial' or 'final'
  String? get resultType => data['resultType'] as String?;

  /// Timestamp of the caption
  int? get timestamp => data['timestamp'] as int?;
}

/// Event emitted when real-time text (RTT) arrives.
///
/// Common event types include:
/// - `messageReceived`: RTT message received from a participant
/// - `messageSent`: RTT message sent confirmation
class RealTimeTextEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const RealTimeTextEvent({required this.type, required this.data});

  factory RealTimeTextEvent.fromMap(Map<String, dynamic> map) {
    return RealTimeTextEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// The RTT message text
  String? get text => data['text'] as String?;

  /// The sender's identifier
  String? get senderRawId => data['senderRawId'] as String?;

  /// The sender's display name
  String? get senderName => data['senderName'] as String?;

  /// Sequence number of the message
  int? get sequenceId => data['sequenceId'] as int?;

  /// Whether this is a finalized message or in-progress typing
  bool? get isFinalized => data['isFinalized'] as bool?;

  /// Timestamp of when the message was received
  int? get receivedTime => data['receivedTime'] as int?;

  /// Timestamp of when the message was last updated
  int? get updatedTime => data['updatedTime'] as int?;
}

/// Event emitted for data channel updates.
///
/// Common event types include:
/// - `messageReceived`: Data message received
/// - `channelClosed`: Data channel was closed
/// - `receiverCreated`: New data channel receiver created
class DataChannelEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const DataChannelEvent({required this.type, required this.data});

  factory DataChannelEvent.fromMap(Map<String, dynamic> map) {
    return DataChannelEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// The binary payload of the data channel message
  Uint8List? get payload {
    final d = data['data'];
    if (d is Uint8List) return d;
    if (d is List<int>) return Uint8List.fromList(d);
    return null;
  }

  /// The channel ID
  int? get channelId => data['channelId'] as int?;

  /// The sender's identifier
  String? get senderRawId => data['senderRawId'] as String?;

  /// Sequence number of the message
  int? get sequenceNumber => data['sequenceNumber'] as int?;
}

/// Event emitted when media statistics reports arrive.
///
/// Contains aggregated statistics about audio and video streams.
///
/// Units in the per-stream maps: bitrates are bits per second, jitter and
/// freeze durations are milliseconds, and `packetsLostPerSecond` is a rate
/// (packets lost per second), not a running total. Incoming audio statistics
/// carry no participant identifier (a limitation of the underlying SDK), so
/// they cannot be attributed to a specific remote participant.
class MediaStatisticsEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const MediaStatisticsEvent({required this.type, required this.data});

  factory MediaStatisticsEvent.fromMap(Map<String, dynamic> map) {
    return MediaStatisticsEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// Safely converts a nested map from platform channel to a typed Map.
  static Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Safely converts a list of maps from platform channel.
  static List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    return value
        .map((e) =>
            e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }

  /// Helper to get the report object from data.
  /// iOS SDK wraps statistics in: { "type": "...", "report": { actual data } }
  Map<String, dynamic>? get _report => _toStringDynamicMap(data['report']);

  /// Outgoing audio statistics (first stream, for convenience)
  /// iOS SDK structure: data['report']['outgoing']['audio'][0]
  Map<String, dynamic>? get outgoingAudio {
    final report = _report;
    if (report == null) return null;
    final outgoing = _toStringDynamicMap(report['outgoing']);
    if (outgoing == null) return null;
    final audioList = _toMapList(outgoing['audio']);
    if (audioList.isEmpty) return null;
    return audioList.first;
  }

  /// All outgoing audio streams
  List<Map<String, dynamic>> get outgoingAudioList {
    final report = _report;
    if (report == null) return const [];
    final outgoing = _toStringDynamicMap(report['outgoing']);
    if (outgoing == null) return const [];
    return _toMapList(outgoing['audio']);
  }

  /// Incoming audio statistics (first stream, for convenience)
  /// iOS SDK structure: data['report']['incoming']['audio'][0]
  Map<String, dynamic>? get incomingAudio {
    final report = _report;
    if (report == null) return null;
    final incoming = _toStringDynamicMap(report['incoming']);
    if (incoming == null) return null;
    final audioList = _toMapList(incoming['audio']);
    if (audioList.isEmpty) return null;
    return audioList.first;
  }

  /// All incoming audio streams
  List<Map<String, dynamic>> get incomingAudioList {
    final report = _report;
    if (report == null) return const [];
    final incoming = _toStringDynamicMap(report['incoming']);
    if (incoming == null) return const [];
    return _toMapList(incoming['audio']);
  }

  /// Outgoing video statistics (first stream, for convenience)
  /// iOS SDK structure: data['report']['outgoing']['video'][0]
  Map<String, dynamic>? get outgoingVideo {
    final report = _report;
    if (report == null) return null;
    final outgoing = _toStringDynamicMap(report['outgoing']);
    if (outgoing == null) return null;
    final videoList = _toMapList(outgoing['video']);
    if (videoList.isEmpty) return null;
    return videoList.first;
  }

  /// All outgoing video streams
  List<Map<String, dynamic>> get outgoingVideoList {
    final report = _report;
    if (report == null) return const [];
    final outgoing = _toStringDynamicMap(report['outgoing']);
    if (outgoing == null) return const [];
    return _toMapList(outgoing['video']);
  }

  /// Incoming video statistics (list of remote participant video stats)
  /// iOS SDK structure: data['report']['incoming']['video']
  List<Map<String, dynamic>> get incomingVideo {
    final report = _report;
    if (report == null) return const [];
    final incoming = _toStringDynamicMap(report['incoming']);
    if (incoming == null) return const [];
    return _toMapList(incoming['video']);
  }

  /// Outgoing screen share statistics
  /// iOS SDK structure: data['report']['outgoing']['screenShare'][0]
  Map<String, dynamic>? get outgoingScreenShare {
    final report = _report;
    if (report == null) return null;
    final outgoing = _toStringDynamicMap(report['outgoing']);
    if (outgoing == null) return null;
    final screenShareList = _toMapList(outgoing['screenShare']);
    if (screenShareList.isEmpty) return null;
    return screenShareList.first;
  }

  /// Incoming screen share statistics
  /// iOS SDK structure: data['report']['incoming']['screenShare']
  List<Map<String, dynamic>> get incomingScreenShare {
    final report = _report;
    if (report == null) return const [];
    final incoming = _toStringDynamicMap(report['incoming']);
    if (incoming == null) return const [];
    return _toMapList(incoming['screenShare']);
  }

  /// When these statistics were collected, in milliseconds since the epoch.
  ///
  /// Both platforms send epoch milliseconds in `report['lastUpdated']`. To stay
  /// tolerant of older iOS builds that sent an ISO-8601 string, a numeric value is
  /// taken as milliseconds, a string is parsed with [DateTime.tryParse], and any
  /// other or unusable value falls back to `data['timestamp']`. Never throws;
  /// `null` when nothing usable is present.
  int? get timestamp {
    final fromReport = _epochMillis(_report?['lastUpdated']);
    return fromReport ?? _epochMillis(data['timestamp']);
  }

  /// Converts a number (epoch ms) or ISO-8601 string to epoch ms; else `null`.
  static int? _epochMillis(dynamic value) {
    // isFinite guard: NaN/Infinity make toInt() throw.
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }
}

/// Event emitted when diagnostics change.
///
/// Contains information about call quality issues including:
/// - Network diagnostics (connection, bandwidth)
/// - Media diagnostics (audio/video device issues)
/// - User facing diagnostics (muted while speaking, etc.)
class DiagnosticsEvent {
  /// The event type identifier
  final String type;

  /// Raw event data for backward compatibility
  final Map<String, dynamic> data;

  const DiagnosticsEvent({required this.type, required this.data});

  factory DiagnosticsEvent.fromMap(Map<String, dynamic> map) {
    return DiagnosticsEvent(
      type: map['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(map),
    );
  }

  /// The specific diagnostic that changed (e.g. `isNetworkUnavailable`).
  ///
  /// Reads `diagnostic`, falling back to `name` for payloads that only carry it.
  String? get diagnostic {
    final diagnostic = data['diagnostic'];
    if (diagnostic is String) return diagnostic;
    final name = data['name'];
    return name is String ? name : null;
  }

  /// The diagnostic value for flag diagnostics; `null` for quality diagnostics
  /// or an unusable payload; `null` means unknown, not `false`. Reads `valueBool`,
  /// falling back to a boolean `value`.
  bool? get valueBool {
    final valueBool = data['valueBool'];
    if (valueBool is bool) return valueBool;
    final value = data['value'];
    return value is bool ? value : null;
  }

  /// The value of a quality diagnostic as a lower-case string (`good`, `poor`,
  /// `bad`, `unknown`); `null` for flag diagnostics or an unusable payload, where
  /// `null` means unknown, not a particular quality.
  /// Reads `valueQuality`, falling back to the lower-cased string `value`
  /// (Android sends upper-case, iOS lower-case, in `value`).
  String? get valueQuality {
    final valueQuality = data['valueQuality'];
    if (valueQuality is String) return valueQuality.toLowerCase();
    final value = data['value'];
    return value is String ? value.toLowerCase() : null;
  }

  /// Whether this is a flag-type diagnostic (true/false) rather than a quality
  /// one. Uses `isFlagDiagnostic` when present, else infers from a string `value`.
  /// This says which kind of diagnostic it is; it is not the flag's value (see
  /// [valueBool], where `null` means unknown, not `false`).
  bool get isFlagDiagnostic {
    final flag = data['isFlagDiagnostic'];
    if (flag is bool) return flag;
    return data['value'] is! String;
  }

  /// Safely converts a nested map from platform channel to a typed Map.
  static Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Network diagnostics snapshot (`diagnosticsSnapshot` events and
  /// `getLatestDiagnostics`). Quality values keep each platform's casing
  /// (Android upper-case, iOS lower-case); compare case-insensitively.
  Map<String, dynamic>? get networkDiagnostics =>
      _toStringDynamicMap(data['network']);

  /// Media diagnostics snapshot. The camera-frozen flag is under both
  /// `isCameraFrozen` (canonical) and `isCameraFreeze` (legacy alias) on both
  /// platforms.
  Map<String, dynamic>? get mediaDiagnostics =>
      _toStringDynamicMap(data['media']);
}

/// Current captions configuration/state.
class CaptionsState {
  final bool available;
  final bool isEnabled;
  final String type;
  final String activeSpokenLanguage;
  final String? activeCaptionLanguage;
  final List<String> supportedSpokenLanguages;
  final List<String> supportedCaptionLanguages;

  const CaptionsState({
    required this.available,
    required this.isEnabled,
    required this.type,
    required this.activeSpokenLanguage,
    required this.activeCaptionLanguage,
    required this.supportedSpokenLanguages,
    required this.supportedCaptionLanguages,
  });

  factory CaptionsState.fromMap(Map<String, dynamic> map) {
    return CaptionsState(
      available: map['available'] != false,
      isEnabled: map['isEnabled'] as bool? ?? false,
      type: map['type'] as String? ?? 'unknown',
      activeSpokenLanguage: map['activeSpokenLanguage'] as String? ?? '',
      activeCaptionLanguage: map['activeCaptionLanguage'] as String?,
      supportedSpokenLanguages:
          (map['supportedSpokenLanguages'] as List<dynamic>?)?.cast<String>() ??
              const [],
      supportedCaptionLanguages:
          (map['supportedCaptionLanguages'] as List<dynamic>?)
                  ?.cast<String>() ??
              const [],
    );
  }
}

/// Raised hand entry.
class RaisedHandInfo {
  final String identifier;
  final int order;

  const RaisedHandInfo({required this.identifier, required this.order});

  factory RaisedHandInfo.fromMap(Map<String, dynamic> map) {
    return RaisedHandInfo(
      identifier: map['identifier'] as String? ?? '',
      order: map['order'] as int? ?? 0,
    );
  }
}

/// Data channel sender metadata.
class DataChannelSenderInfo {
  final int channelId;
  final int maxMessageSizeInBytes;

  const DataChannelSenderInfo({
    required this.channelId,
    required this.maxMessageSizeInBytes,
  });

  factory DataChannelSenderInfo.fromMap(Map<String, dynamic> map) {
    return DataChannelSenderInfo(
      channelId: map['channelId'] as int? ?? 0,
      maxMessageSizeInBytes: map['maxMessageSizeInBytes'] as int? ?? 0,
    );
  }
}

/// Survey handle returned when starting a survey.
class CallSurveyHandle {
  final String handle;

  const CallSurveyHandle(this.handle);

  factory CallSurveyHandle.fromMap(Map<String, dynamic> map) {
    return CallSurveyHandle(map['handle'] as String? ?? '');
  }
}

/// Survey submission result.
class CallSurveyResult {
  final String surveyId;
  final String callId;
  final String anonymizedParticipantId;

  const CallSurveyResult({
    required this.surveyId,
    required this.callId,
    required this.anonymizedParticipantId,
  });

  factory CallSurveyResult.fromMap(Map<String, dynamic> map) {
    return CallSurveyResult(
      surveyId: map['surveyId'] as String? ?? '',
      callId: map['callId'] as String? ?? '',
      anonymizedParticipantId: map['anonymizedParticipantId'] as String? ?? '',
    );
  }
}

/// Input for a survey rating scale.
class CallSurveyRatingScaleInput {
  final int? lowerBound;
  final int? upperBound;
  final int? lowScoreThreshold;

  const CallSurveyRatingScaleInput({
    this.lowerBound,
    this.upperBound,
    this.lowScoreThreshold,
  });

  Map<String, dynamic> toMap() {
    return {
      if (lowerBound != null) 'lowerBound': lowerBound,
      if (upperBound != null) 'upperBound': upperBound,
      if (lowScoreThreshold != null) 'lowScoreThreshold': lowScoreThreshold,
    };
  }
}

/// Input for a survey score.
class CallSurveyScoreInput {
  final int score;
  final CallSurveyRatingScaleInput? scale;

  const CallSurveyScoreInput({required this.score, this.scale});

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      if (scale != null) 'scale': scale!.toMap(),
    };
  }
}

/// Payload for submitting a call survey.
class CallSurveySubmission {
  final CallSurveyHandle handle;
  final CallSurveyScoreInput? overallScore;
  final CallSurveyScoreInput? audioScore;
  final CallSurveyScoreInput? videoScore;
  final CallSurveyScoreInput? screenShareScore;
  final int? overallIssues;
  final int? audioIssues;
  final int? videoIssues;
  final int? screenShareIssues;

  const CallSurveySubmission({
    required this.handle,
    this.overallScore,
    this.audioScore,
    this.videoScore,
    this.screenShareScore,
    this.overallIssues,
    this.audioIssues,
    this.videoIssues,
    this.screenShareIssues,
  });

  Map<String, dynamic> toMap() {
    return {
      'handle': handle.handle,
      if (overallScore != null) 'overallScore': overallScore!.toMap(),
      if (audioScore != null) 'audioScore': audioScore!.toMap(),
      if (videoScore != null) 'videoScore': videoScore!.toMap(),
      if (screenShareScore != null)
        'screenShareScore': screenShareScore!.toMap(),
      if (overallIssues != null) 'overallIssues': overallIssues,
      if (audioIssues != null) 'audioIssues': audioIssues,
      if (videoIssues != null) 'videoIssues': videoIssues,
      if (screenShareIssues != null) 'screenShareIssues': screenShareIssues,
    };
  }
}
