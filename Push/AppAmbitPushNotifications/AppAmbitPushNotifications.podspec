Pod::Spec.new do |s|
  s.name             = 'AppAmbitPushNotifications'
  s.version          = '1.0.0'
  s.summary          = 'Facades the AppAmbit Push kernel over APNs for iOS apps.'

  s.description      = <<-DESC
    The AppAmbitPushNotifications pod exposes the Swift push notification facade that mirrors the Android
    PushNotifications API and syncs APNs tokens with the AppAmbit backend.
  DESC

  s.homepage         = 'https://github.com/AppAmbit/appambit-sdk-ios'
  s.license          = { :type => 'MIT', :file => '../../LICENSE' }
  s.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  s.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.swift_version  = '5.7'

  s.source_files = 'Sources/**/*.{swift}'
  s.dependency 'AppAmbitSdk', '>= 0.1.1'
end
