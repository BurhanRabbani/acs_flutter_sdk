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
  Object? devicesReturn;

  late AcsCallClient client;

  setUp(() {
    log.clear();
    getAudioRouteReturn = 'speaker';
    availableReturn = <String>['auto', 'speaker', 'earpiece'];
    devicesReturn = null;
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
        case 'getAvailableAudioOutputDevices':
          return devicesReturn;
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

  group('getAvailableAudioOutputDevices', () {
    test('maps type and name entries into AudioOutputDevice values', () async {
      devicesReturn = <Map<String, Object?>>[
        {'type': 'auto', 'name': null},
        {'type': 'speaker', 'name': 'Pixel 8'},
        {'type': 'bluetooth', 'name': 'AirPods Pro'},
      ];
      final devices = await client.getAvailableAudioOutputDevices();
      expect(devices, const <AudioOutputDevice>[
        AudioOutputDevice(type: AudioOutput.auto),
        AudioOutputDevice(type: AudioOutput.speaker, name: 'Pixel 8'),
        AudioOutputDevice(type: AudioOutput.bluetooth, name: 'AirPods Pro'),
      ]);
      expect(log.single.method, 'getAvailableAudioOutputDevices');
    });

    test('falls back to auto + speaker with null names on a null payload',
        () async {
      devicesReturn = null;
      expect(await client.getAvailableAudioOutputDevices(), const [
        AudioOutputDevice(type: AudioOutput.auto),
        AudioOutputDevice(type: AudioOutput.speaker),
      ]);
    });

    test('falls back the same way on a non-List payload', () async {
      devicesReturn = 'not a list';
      expect(await client.getAvailableAudioOutputDevices(), const [
        AudioOutputDevice(type: AudioOutput.auto),
        AudioOutputDevice(type: AudioOutput.speaker),
      ]);
    });

    test('skips non-map entries and entries with unknown or missing type',
        () async {
      devicesReturn = <Object?>[
        'speaker',
        42,
        null,
        {'type': 'hologram', 'name': 'x'},
        {'name': 'no type'},
        {'type': 'earpiece', 'name': 'iPhone'},
      ];
      expect(await client.getAvailableAudioOutputDevices(), const [
        AudioOutputDevice(type: AudioOutput.earpiece, name: 'iPhone'),
      ]);
    });

    test('treats non-string and empty names as null', () async {
      devicesReturn = <Object?>[
        {'type': 'speaker', 'name': 7},
        {'type': 'earpiece', 'name': ''},
      ];
      expect(await client.getAvailableAudioOutputDevices(), const [
        AudioOutputDevice(type: AudioOutput.speaker),
        AudioOutputDevice(type: AudioOutput.earpiece),
      ]);
    });
  });

  group('AudioOutputDevice', () {
    test('has value equality and a readable toString', () {
      const a = AudioOutputDevice(type: AudioOutput.bluetooth, name: 'Buds');
      const b = AudioOutputDevice(type: AudioOutput.bluetooth, name: 'Buds');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AudioOutputDevice(type: AudioOutput.bluetooth)));
      expect(a.toString(), 'AudioOutputDevice(type: bluetooth, name: Buds)');
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
