#
#  Be sure to run `pod spec lint AppAmbitSdk.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name             = 'AppAmbitSdk'
  s.version          = '0.0.1'
  s.summary          = 'Lightweight SDK for capturing sessions, logs, crashes, and events in iOS apps with offline persistence and batch upload to AppAmbit.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
AppAmbit SDK lets you capture sessions, logs, crashes, and custom events in your iOS apps. It supports offline persistence and batches data to AppAmbit backend services with minimal setup.
                       DESC

  s.homepage         = 'https://appambit.com'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  s.source           = { :git => 'https://github.com/AppAmbit/appambit-sdk-ios.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  
  s.swift_version  = '5.9'


  s.source_files = 'Sources/**/*.swift'
  
  # s.resource_bundles = {
  #   'AppSdkTest' => ['AppSdkTest/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
