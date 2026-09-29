import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the in-call noise-suppression API on [AcsCallClient] encodes its
/// method-channel arguments and surfaces platform failures as
/// [AcsCallingException].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('acs_flutter_sdk');
  final List<MethodCall> log = <MethodCall>[];

  /// When true the mock behaves as if no call is active.
  bool noActiveCall = false;

  /// When set, the mock fails with this code instead of succeeding.
  String? failureCode;
  Object? modeReturn = 'auto';

  late AcsCallClient client;

  setUp(() {
    log.clear();
    noActiveCall = false;
    failureCode = null;
    modeReturn = 'auto';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      if (noActiveCall) {
        throw PlatformException(
            code: 'NO_ACTIVE_CALL', message: 'No active call');
      }
      if (failureCode != null) {
        throw PlatformException(code: failureCode!, message: 'sdk said no');
      }
      return call.method == 'getNoiseSuppressionMode' ? modeReturn : null;
    });
    client = AcsCallClient(channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('setNoiseSuppressionMode', () {
    test('sends the lower-cased mode for every supported value', () async {
      for (final mode in ['off', 'auto', 'low', 'high']) {
        log.clear();
        await client.setNoiseSuppressionMode(mode);
        expect(log.single.method, 'setNoiseSuppressionMode');
        expect(log.single.arguments, {'mode': mode});
      }
    });

    test('is case-insensitive', () async {
      await client.setNoiseSuppressionMode('HIGH');
      expect(log.single.arguments, {'mode': 'high'});
    });

    test('rejects unknown and empty modes via a failed Future, no channel call',
        () async {
      for (final bad in ['max', '']) {
        await expectLater(
            client.setNoiseSuppressionMode(bad), throwsArgumentError);
      }
      expect(log, isEmpty);
    });

    test('propagates NOISE_SUPPRESSION_FAILED from the platform', () async {
      failureCode = 'NOISE_SUPPRESSION_FAILED';
      await expectLater(
        client.setNoiseSuppressionMode('low'),
        throwsA(isA<AcsCallingException>()
            .having((e) => e.code, 'code', 'NOISE_SUPPRESSION_FAILED')),
      );
    });

    test('throws AcsCallingException NO_ACTIVE_CALL without a call', () async {
      noActiveCall = true;
      expect(
        client.setNoiseSuppressionMode('low'),
        throwsA(isA<AcsCallingException>()
            .having((e) => e.code, 'code', 'NO_ACTIVE_CALL')),
      );
    });
  });

  group('getNoiseSuppressionMode', () {
    test('returns the platform mode', () async {
      modeReturn = 'high';
      expect(await client.getNoiseSuppressionMode(), 'high');
      expect(log.single.method, 'getNoiseSuppressionMode');
    });

    test('returns null for an unexpected value', () async {
      modeReturn = 'ultra';
      expect(await client.getNoiseSuppressionMode(), isNull);
    });

    test('returns null when the platform reports nothing', () async {
      modeReturn = null;
      expect(await client.getNoiseSuppressionMode(), isNull);
    });

    test('throws AcsCallingException NO_ACTIVE_CALL without a call', () async {
      noActiveCall = true;
      expect(
        client.getNoiseSuppressionMode(),
        throwsA(isA<AcsCallingException>()
            .having((e) => e.code, 'code', 'NO_ACTIVE_CALL')),
      );
    });
  });
}
