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

  # Full SDK for the host app (Core + Delegate + Extension).
  # Not extension-safe — references UIApplication and other APIs forbidden
  # in Notification Service Extensions. For NSE targets use the
  # `AppAmbitPushNotificationsExtension` pod instead.
  spec.source_files = 'Sources/**/*.swift'
  spec.dependency 'AppAmbitSdk'
end
