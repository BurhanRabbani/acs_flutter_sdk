#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint acs_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'acs_flutter_sdk'
  s.version          = '0.1.3'
  s.summary          = 'Flutter plugin for Microsoft Azure Communication Services'
  s.description      = <<-DESC
A comprehensive Flutter plugin that provides a wrapper for Microsoft Azure Communication Services (ACS),
enabling voice/video calling, chat, SMS, and identity management capabilities in Flutter applications.
                       DESC
  s.homepage         = 'https://github.com/BurhanRabbani/acs_flutter_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Burhan Rabbani' => 'burhanrabbani@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Azure Communication Services dependencies
  # OPTIMIZATION: Removed AzureCommunicationChat (not used, saves ~50-80 MB)
  #
  # AzureCommunicationCalling is resolved from CocoaPods, pinned to the 2.15.x line so it
  # stays compatible with AzureCommunicationUICalling (CallComposite), which hard-pins Calling
  # to exactly 2.15.0. AzureCommunicationCommon is pulled in transitively by Calling.
  s.dependency 'AzureCommunicationCalling', '~> 2.15.0'
  # s.dependency 'AzureCommunicationChat', '~> 1.3.6'  # OPTIMIZATION: Removed (not used)
  # Native CallComposite UI Library (drives AcsUiLibraryPlugin). It hard-pins Calling to
  # exactly 2.15.0, so the two must always move together.
  s.dependency 'AzureCommunicationUICalling', '~> 1.14.2'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest for iOS 17+ App Store compliance
  # See https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'acs_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
