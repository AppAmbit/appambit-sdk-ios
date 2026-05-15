Pod::Spec.new do |spec|
  spec.name         = "AppAmbitPushNotifications"
  spec.version      = "0.5.0"
  spec.summary      = "Push Notifications SDK for iOS to send push notifications via AppAmbit platform."

  spec.description  = <<-DESC
  Push Notifications SDK for iOS to send push notifications via AppAmbit platform.
                   DESC

  spec.homepage     = "https://github.com/AppAmbit/appambit-sdk-ios"
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  spec.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => spec.version.to_s }
  spec.documentation_url = "https://raw.githubusercontent.com/AppAmbit/appambit-sdk-ios/main/Push/AppAmbitPushNotifications/README.md"

  spec.ios.deployment_target = '12.0'
  spec.swift_version  = '5.7'

  spec.default_subspec = 'Core'

  # Full SDK — for the host app. Includes Core/Delegate/Extension code and
  # depends on the main AppAmbit SDK.
  spec.subspec 'Core' do |c|
    c.source_files = 'Sources/**/*.swift'
    c.dependency 'AppAmbitSdk'
  end

  # Extension-only — for the Notification Service Extension target.
  # Self-contained (no AppAmbitSdk / no Core dependency) and compiled with
  # APPLICATION_EXTENSION_API_ONLY so it cannot accidentally reference APIs
  # forbidden in app extensions.
  spec.subspec 'Extension' do |e|
    e.source_files = 'Sources/Extension/*.swift'
    e.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
  end
end
