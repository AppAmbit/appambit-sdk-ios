Pod::Spec.new do |spec|
  spec.name         = "AppAmbitPushNotificationsExtension"
  spec.version      = "0.5.0"
  spec.summary      = "Extension-safe slice of AppAmbitPushNotifications for iOS Notification Service Extensions."

  spec.description  = <<-DESC
  Extension-only subset of the AppAmbit Push Notifications SDK, compiled with
  APPLICATION_EXTENSION_API_ONLY = YES so it can be linked into a Notification
  Service Extension target. Provides the `AppAmbitNotificationService` base
  class, `AppAmbitNotification` model and `PushNotificationAttachments` helper.

  Self-contained: depends only on UserNotifications and Foundation. Does not
  pull in the main AppAmbit SDK.
                   DESC

  spec.homepage     = "https://github.com/AppAmbit/appambit-sdk-ios"
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  spec.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => spec.version.to_s }

  spec.ios.deployment_target = '12.0'
  spec.swift_version  = '5.7'

  spec.source_files = 'Sources/Extension/*.swift'
  spec.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
end
