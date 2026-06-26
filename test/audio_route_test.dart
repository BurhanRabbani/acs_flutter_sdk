import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the dynamic audio-output API on [AcsCallClient] sends the right
/// method-channel calls and parses platform responses into [AudioOutput] values.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('acs_flutter_sdk');
  final List<MethodCall> log = <MethodCall>[];

  // Platform values the mock returns for the read APIs.
  String getAudioRouteReturn = 'speaker';
  List<String> availableReturn = <String>['auto', 'speaker', 'earpiece'];

  late AcsCallClient client;

  setUp(() {
    log.clear();
    getAudioRouteReturn = 'speaker';
    availableReturn = <String>['auto', 'speaker', 'earpiece'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'setAudioRoute':
          return null;
        case 'getAudioRoute':
          return getAudioRouteReturn;
        case 'getAvailableAudioOutputs':
          return availableReturn;
        default:
          return null;
      }
    });
    client = AcsCallClient(channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('setAudioRoute', () {
    test('sends setAudioRoute with the target enum name for every value',
        () async {
      for (final target in AudioOutput.values) {
        log.clear();
        await client.setAudioRoute(target);
        expect(log, hasLength(1));
        expect(log.single.method, 'setAudioRoute');
        expect(log.single.arguments, {'target': target.name});
      }
    });
  });

  group('getAudioRoute', () {
    test('parses the returned name into an AudioOutput', () async {
      getAudioRouteReturn = 'earpiece';
      final route = await client.getAudioRoute();
      expect(route, AudioOutput.earpiece);
      expect(log.single.method, 'getAudioRoute');
    });

    test('falls back to auto for an unknown platform value', () async {
      getAudioRouteReturn = 'something-new';
      expect(await client.getAudioRoute(), AudioOutput.auto);
    });
  });

  group('getAvailableAudioOutputs', () {
    test('maps the returned names into AudioOutput values', () async {
      availableReturn = <String>['auto', 'speaker', 'earpiece', 'bluetooth'];
      final outputs = await client.getAvailableAudioOutputs();
      expect(outputs, <AudioOutput>[
        AudioOutput.auto,
        AudioOutput.speaker,
        AudioOutput.earpiece,
        AudioOutput.bluetooth,
      ]);
      expect(log.single.method, 'getAvailableAudioOutputs');
    });

    test('unknown names degrade to auto rather than throwing', () async {
      availableReturn = <String>['speaker', 'mystery'];
      final outputs = await client.getAvailableAudioOutputs();
      expect(outputs, <AudioOutput>[AudioOutput.speaker, AudioOutput.auto]);
    });
  });

  group('audioOutputFromName', () {
    test('round-trips every enum name', () {
      for (final value in AudioOutput.values) {
        expect(audioOutputFromName(value.name), value);
      }
    });

    test('returns auto for null/unknown', () {
      expect(audioOutputFromName(null), AudioOutput.auto);
      expect(audioOutputFromName('nope'), AudioOutput.auto);
    });
  });
}
