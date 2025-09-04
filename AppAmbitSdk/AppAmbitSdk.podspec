#
#  Be sure to run `pod spec lint AppAmbitSdk.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name             = 'AppAmbitSdk'
  s.version          = '1.0.0'
  s.summary          = 'AppAmbit SDK is a lightweight telemetry and logging solution for iOS apps.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
AppAmbit SDK provides a unified way to capture sessions, logs, crashes, and custom events from your iOS applications. It is designed for developers who want reliable telemetry, offline persistence, and batch delivery to AppAmbit backend services, without heavy configuration.
                       DESC

  s.homepage         = 'https://github.com/Kava-Up-LLC/appambit-sdk-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AppAmbit Inc' => 'hello@appambit.com' }
  s.source           = { :git => 'https://github.com/Kava-Up-LLC/appambit-sdk-ios.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  
  s.swift_version  = '5.9'                     # default
  s.swift_versions = ['5.7', '5.8', '5.9']     # support


  s.source_files = 'Sources/**/*.swift'
  
  # s.resource_bundles = {
  #   'AppSdkTest' => ['AppSdkTest/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
