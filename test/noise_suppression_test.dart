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
  Object? modeReturn = 'auto';

  late AcsCallClient client;

  setUp(() {
    log.clear();
    noActiveCall = false;
    modeReturn = 'auto';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      if (noActiveCall) {
        throw PlatformException(
            code: 'NO_ACTIVE_CALL', message: 'No active call');
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

    test('rejects an unknown mode without calling the platform', () async {
      expect(() => client.setNoiseSuppressionMode('max'), throwsArgumentError);
      expect(log, isEmpty);
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
