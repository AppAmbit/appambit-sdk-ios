Pod::Spec.new do |s|
  s.name             = 'AppAmbitSdk'
  s.version          = '0.0.1'
  s.summary          = 'Lightweight SDK for capturing sessions, logs, crashes, and events in iOS apps with offline persistence and batch upload to AppAmbit.'
  s.description      = <<-DESC
AppAmbit SDK lets you capture sessions, logs, crashes, and custom events in your iOS apps. It supports offline persistence and batches data to AppAmbit backend services with minimal setup.
  DESC

  s.homepage         = 'https://appambit.coms'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }


  s.source           = { :git => 'https://github.com/Kava-Up-LLC/appambit-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.static_framework = true

  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }

  s.source_files = 'Sources/**/*.swift'
end
