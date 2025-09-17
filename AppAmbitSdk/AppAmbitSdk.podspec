Pod::Spec.new do |s|
  s.name             = 'AppAmbitSdk'
  s.version          = '0.0.6'
  s.summary          = 'Lightweight SDK for capturing sessions, logs, crashes, and events in iOS apps with offline persistence and batch upload to AppAmbit.'

  s.description      = <<-DESC
AppAmbit SDK lets you capture sessions, logs, crashes, and custom events in your iOS apps. It supports offline persistence and batches data to AppAmbit backend services with minimal setup.
                       DESC

  s.homepage         = 'https://github.com/AppAmbit/appambit-sdk-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  s.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  
  s.swift_version  = '5.7'

  s.source_files = [
    'Sources/**/*.swift',
    'AppAmbitSdk/Sources/**/*.swift'
  ]
end
