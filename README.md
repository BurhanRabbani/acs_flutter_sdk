# Azure Communication Services Flutter SDK

A comprehensive Flutter plugin that provides a wrapper for Microsoft Azure Communication Services (ACS), enabling voice/video calling, chat, SMS, and identity management capabilities in Flutter applications.

[![pub package](https://img.shields.io/pub/v/acs_flutter_sdk.svg)](https://pub.dev/packages/acs_flutter_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **Identity Management**: Create users and manage access tokens
- ✅ **Voice & Video Calling**: Make and receive voice and video calls with full call controls
- ✅ **Chat**: Send and receive messages in chat threads with real-time notifications
- ✅ **Cross-platform**: Supports both Android and iOS
- ✅ **Type-safe**: Built with sound null safety
- ✅ **Well-documented**: Comprehensive API documentation and examples

## Platform Support

| Platform | Supported | Minimum Version |
|----------|-----------|----------------|
| Android  | ✅        | API 24 (Android 7.0) |
| iOS      | ✅        | iOS 13.0+ |

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  acs_flutter_sdk: ^0.1.0
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Ensure your `android/app/build.gradle` has minimum SDK version 24:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

#### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for calls</string>
```

Ensure your `ios/Podfile` has minimum iOS version 13.0:

```ruby
platform :ios, '13.0'
```

## Usage

### Basic Setup

```dart
import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';

// Initialize the SDK
final sdk = AcsFlutterSdk();
```

### Identity Management

**Important**: For production applications, identity operations (creating users and generating tokens) should be performed server-side for security. The SDK provides these methods for development and testing purposes.

```dart
// Create an identity client
final identityClient = sdk.createIdentityClient();

// Initialize with your connection string (server-side recommended)
await identityClient.initialize('your-connection-string');

// Note: In production, call your backend API to create users and get tokens
// Example server-side flow:
// 1. Your app requests a token from your backend
// 2. Your backend creates a user and generates a token using ACS SDK
// 3. Your backend returns the token to your app
// 4. Your app uses the token to initialize calling/chat clients
```

### Voice & Video Calling

```dart
// Create a calling client
final callingClient = sdk.createCallClient();

// Initialize with an access token (obtained from your backend)
await callingClient.initialize('your-access-token');

// Start a call to one or more participants
final call = await callingClient.startCall(
  ['user-id-1', 'user-id-2'],
  withVideo: true,
);

// Join an existing group call
final call = await callingClient.joinCall(
  'group-call-id',
  withVideo: false,
);

// Mute/unmute audio
await callingClient.muteAudio();
await callingClient.unmuteAudio();

// Start/stop video
await callingClient.startVideo();
await callingClient.stopVideo();

// End the call
await callingClient.endCall();

// Listen to call state changes
callingClient.callStateStream.listen((state) {
  print('Call state: $state');
});
```

### Chat

```dart
// Create a chat client
final chatClient = sdk.createChatClient();

// Initialize with an access token (obtained from your backend)
await chatClient.initialize('your-access-token');

// Create a new chat thread
final thread = await chatClient.createChatThread(
  'My Chat Thread',
  ['user-id-1', 'user-id-2'],
);

// Join an existing chat thread
final thread = await chatClient.joinChatThread('thread-id');

// Send a message
final messageId = await chatClient.sendMessage(
  thread.id,
  'Hello, world!',
);

// Get messages from a thread
final messages = await chatClient.getMessages(thread.id, maxMessages: 50);

// Send typing notification
await chatClient.sendTypingNotification(thread.id);

// Listen to incoming messages
chatClient.messageStream.listen((message) {
  print('New message: ${message.content}');
});

// Listen to typing indicators
chatClient.typingIndicatorStream.listen((indicator) {
  print('${indicator.userId} is typing...');
});
```



## Architecture

This plugin uses Method Channels for communication between Flutter (Dart) and native platforms (Android/iOS):

```
┌─────────────────────────────────────┐
│         Flutter (Dart)              │
│  ┌─────────────────────────────┐   │
│  │   AcsFlutterSdk             │   │
│  │  ┌──────────────────────┐   │   │
│  │  │ AcsIdentityClient    │   │   │
│  │  │ AcsCallClient        │   │   │
│  │  │ AcsChatClient        │   │   │
│  │  └──────────────────────┘   │   │
│  └─────────────────────────────┘   │
└──────────────┬──────────────────────┘
               │ Method Channel
┌──────────────┴──────────────────────┐
│      Native Platform Code           │
│  ┌─────────────────────────────┐   │
│  │  Android (Kotlin)           │   │
│  │  - ACS Calling SDK          │   │
│  │  - ACS Chat SDK             │   │
│  │  - ACS Common SDK           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │  iOS (Swift)                │   │
│  │  - ACS Calling SDK          │   │
│  │  - ACS Chat SDK             │   │
│  │  - ACS Common SDK           │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Security Best Practices

1. **Never expose connection strings in client apps**: Connection strings should only be used server-side
2. **Implement token refresh**: Access tokens expire and should be refreshed through your backend
3. **Use server-side identity management**: Create users and generate tokens on your backend
4. **Validate permissions**: Ensure users have appropriate permissions before granting access
5. **Secure token storage**: Store tokens securely using platform-specific secure storage

## Example App

A complete example application is included in the `example/` directory. To run it:

```bash
cd example
flutter run
```

## API Reference

For detailed API documentation, see the [API Reference](https://pub.dev/documentation/acs_flutter_sdk/latest/).

## Troubleshooting

### Android Build Issues

If you encounter build issues on Android:

1. Ensure `minSdkVersion` is set to 24 or higher
2. Check that you have the latest Android SDK tools
3. Clean and rebuild: `flutter clean && flutter pub get`

### iOS Build Issues

If you encounter build issues on iOS:

1. Ensure iOS deployment target is 13.0 or higher
2. Run `pod install` in the `ios/` directory
3. Clean and rebuild: `flutter clean && flutter pub get`

### Permission Issues

Ensure all required permissions are added to your platform-specific configuration files as described in the Platform Setup section.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on top of [Azure Communication Services](https://azure.microsoft.com/en-us/services/communication-services/)
- Uses the official Azure Communication Services SDKs for Android and iOS

## Support

For issues and feature requests, please file an issue on [GitHub](https://github.com/yourusername/acs_flutter_sdk/issues).

For Azure Communication Services specific questions, refer to the [official documentation](https://docs.microsoft.com/en-us/azure/communication-services/).
