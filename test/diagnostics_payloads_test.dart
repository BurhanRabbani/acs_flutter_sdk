import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds the payload shapes the Android and iOS layers really emit (not
/// Dart-shaped ones) through the statistics and diagnostics event models.
void main() {
  group('MediaStatisticsEvent.timestamp', () {
    test('reads the epoch-ms int sent by both platforms', () {
      final event = MediaStatisticsEvent.fromMap({
        'type': 'mediaStatisticsReport',
        'report': {'lastUpdated': 1700000000000},
      });
      expect(event.timestamp, 1700000000000);
    });

    test('accepts a double epoch-ms value', () {
      final event = MediaStatisticsEvent.fromMap({
        'type': 'mediaStatisticsReport',
        'report': {'lastUpdated': 1700000000000.0},
      });
      expect(event.timestamp, 1700000000000);
    });

    test('parses an ISO-8601 string from older iOS builds without throwing',
        () {
      final event = MediaStatisticsEvent.fromMap({
        'type': 'mediaStatisticsReport',
        'report': {'lastUpdated': '2023-11-14T22:13:20.000Z'},
      });
      expect(event.timestamp, 1700000000000);
    });

    test('falls back to data[timestamp] when lastUpdated is unusable', () {
      final event = MediaStatisticsEvent.fromMap({
        'type': 'mediaStatisticsReport',
        'timestamp': 42,
        'report': {'lastUpdated': 'garbage'},
      });
      expect(event.timestamp, 42);
    });

    test('non-finite numbers do not throw and fall back', () {
      for (final bad in [
        double.nan,
        double.infinity,
        double.negativeInfinity
      ]) {
        expect(
          MediaStatisticsEvent.fromMap({
            'type': 'x',
            'timestamp': 42,
            'report': {'lastUpdated': bad},
          }).timestamp,
          42,
        );
        expect(
          MediaStatisticsEvent.fromMap({
            'type': 'x',
            'report': {'lastUpdated': bad},
          }).timestamp,
          isNull,
        );
      }
    });

    test('is null, never throws, when nothing is usable', () {
      expect(
        MediaStatisticsEvent.fromMap({
          'type': 'x',
          'report': {'lastUpdated': true},
        }).timestamp,
        isNull,
      );
      expect(MediaStatisticsEvent.fromMap({'type': 'x'}).timestamp, isNull);
    });
  });

  group('DiagnosticsEvent', () {
    test('Android flag change event (native shape)', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'mediaDiagnosticChanged',
        'name': 'isCameraFrozen',
        'value': true,
        'diagnostic': 'isCameraFrozen',
        'isFlagDiagnostic': true,
        'valueBool': true,
      });
      expect(event.diagnostic, 'isCameraFrozen');
      expect(event.valueBool, isTrue);
      expect(event.isFlagDiagnostic, isTrue);
      expect(event.valueQuality, isNull);
    });

    test('Android quality change event (native shape, upper-case value)', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'networkDiagnosticChanged',
        'name': 'networkSendQuality',
        'value': 'GOOD',
        'diagnostic': 'networkSendQuality',
        'isFlagDiagnostic': false,
        'valueQuality': 'good',
      });
      expect(event.diagnostic, 'networkSendQuality');
      expect(event.valueQuality, 'good');
      expect(event.isFlagDiagnostic, isFalse);
      expect(event.valueBool, isNull);
    });

    test('older native quality event with only name/value still works', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'networkDiagnosticChanged',
        'name': 'networkReceiveQuality',
        'value': 'POOR',
      });
      expect(event.diagnostic, 'networkReceiveQuality');
      expect(event.valueQuality, 'poor');
      expect(event.isFlagDiagnostic, isFalse);
      expect(event.valueBool, isNull);
    });

    test('older native flag event with only name/value still works', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'mediaDiagnosticChanged',
        'name': 'isSpeakerMuted',
        'value': false,
      });
      expect(event.diagnostic, 'isSpeakerMuted');
      expect(event.valueBool, isFalse);
      expect(event.isFlagDiagnostic, isTrue);
      expect(event.valueQuality, isNull);
    });

    test('never throws on wrongly typed fields', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'mediaDiagnosticChanged',
        'name': 7,
        'value': 3,
        'diagnostic': 1,
        'valueBool': 'yes',
        'valueQuality': 5,
        'isFlagDiagnostic': 'maybe',
      });
      expect(event.diagnostic, isNull);
      expect(event.valueBool, isNull);
      expect(event.valueQuality, isNull);
      expect(event.isFlagDiagnostic, isTrue);
    });

    test('iOS quality event with an unexpected value prefers valueQuality', () {
      final event = DiagnosticsEvent.fromMap({
        'type': 'networkDiagnosticChanged',
        'name': 'networkSendQuality',
        'value': 'ACSDiagnosticQuality(1)',
        'diagnostic': 'networkSendQuality',
        'isFlagDiagnostic': false,
        'valueQuality': 'good',
      });
      expect(event.valueQuality, 'good');
      expect(event.isFlagDiagnostic, isFalse);
      expect(event.valueBool, isNull);
    });
  });
}
