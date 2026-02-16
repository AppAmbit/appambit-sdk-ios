Pod::Spec.new do |spec|
  spec.name         = "AppAmbitPushNotifications"
  spec.version      = "0.2.0"
  spec.summary      = "Push Notifications SDK for iOS to send push notifications via AppAmbit platform."

  spec.description  = <<-DESC
  Push Notifications SDK for iOS to send push notifications via AppAmbit platform.
                   DESC

  spec.homepage     = "https://github.com/AppAmbit/appambit-sdk-ios"
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  spec.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => spec.version.to_s }

  spec.ios.deployment_target = '12.0'
  spec.swift_version  = '5.7'

  spec.source_files = [
    'Sources/**/*.swift',
    'Push/AppAmbitPushNotifications/Sources/**/*.swift'
  ]
  
  # Dependency on the core AppAmbit SDK
  spec.dependency 'AppAmbitSdk'
end
