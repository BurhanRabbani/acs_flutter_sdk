/// Azure Communication Services Flutter SDK
///
/// A comprehensive Flutter plugin that provides a wrapper for Microsoft Azure
/// Communication Services (ACS), enabling voice/video calling, chat, SMS, and
/// identity management capabilities in Flutter applications.
///
/// ## Features
///
/// - **Identity Management**: Create users and manage access tokens
/// - **Voice & Video Calling**: Make and receive voice and video calls
/// - **Chat**: Send and receive messages in chat threads
/// - **Real-time Notifications**: Receive typing indicators and message notifications
///
/// ## Getting Started
///
/// ### Installation
///
/// Add this to your package's `pubspec.yaml` file:
///
/// ```yaml
/// dependencies:
///   acs_flutter_sdk: ^0.1.0
/// ```
///
/// ### Platform Setup
///
/// #### Android
///
/// Add the following permissions to your `AndroidManifest.xml`:
///
/// ```xml
/// <uses-permission android:name="android.permission.INTERNET" />
/// <uses-permission android:name="android.permission.CAMERA" />
/// <uses-permission android:name="android.permission.RECORD_AUDIO" />
/// <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
/// ```
///
/// #### iOS
///
/// Add the following to your `Info.plist`:
///
/// ```xml
/// <key>NSCameraUsageDescription</key>
/// <string>This app needs camera access for video calls</string>
/// <key>NSMicrophoneUsageDescription</key>
/// <string>This app needs microphone access for calls</string>
/// ```
///
/// ### Usage Example
///
/// ```dart
/// import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
///
/// // Initialize the SDK
/// final sdk = AcsFlutterSdk();
///
/// // Create an identity client
/// final identityClient = sdk.createIdentityClient();
///
/// // Initialize with your connection string (server-side recommended)
/// await identityClient.initialize('your-connection-string');
///
/// // Create a calling client
/// final callingClient = sdk.createCallClient();
///
/// // Initialize with an access token
/// await callingClient.initialize('your-access-token');
///
/// // Start a call
/// final call = await callingClient.startCall(['user-id-1', 'user-id-2']);
/// ```
library;

import 'package:flutter/services.dart';

import 'src/calling/acs_calling.dart';
import 'src/chat/acs_chat.dart';
import 'src/identity/acs_identity.dart';

export 'src/calling/acs_calling.dart';
export 'src/chat/acs_chat.dart';
// Export public APIs
export 'src/identity/acs_identity.dart';
export 'src/models/access_token.dart';
export 'src/models/communication_user.dart';

/// Main entry point for the Azure Communication Services Flutter SDK
///
/// This class provides factory methods for creating clients for different
/// ACS services (identity, calling, chat).
class AcsFlutterSdk {
  static const MethodChannel _channel = MethodChannel('acs_flutter_sdk');

  /// Creates a new identity client for managing users and tokens
  ///
  /// Returns an [AcsIdentityClient] instance
  AcsIdentityClient createIdentityClient() {
    return AcsIdentityClient(_channel);
  }

  /// Creates a new calling client for voice and video calls
  ///
  /// Returns an [AcsCallClient] instance
  AcsCallClient createCallClient() {
    return AcsCallClient(_channel);
  }

  /// Creates a new chat client for messaging
  ///
  /// Returns an [AcsChatClient] instance
  AcsChatClient createChatClient() {
    return AcsChatClient(_channel);
  }

  /// Gets the platform version
  ///
  /// Returns a string describing the platform and version
  Future<String?> getPlatformVersion() async {
    try {
      final String? version = await _channel.invokeMethod('getPlatformVersion');
      return version;
    } catch (e) {
      return null;
    }
  }
}
