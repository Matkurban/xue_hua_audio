#
# iOS + macOS shared implementation of the xue_hua_audio plugin.
# xue_hua_audio 插件的 iOS 与 macOS 共享实现。
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_audio_darwin'
  s.version          = '2.0.0'
  s.summary          = 'iOS and macOS implementation of the xue_hua_audio plugin.'
  s.description      = <<-DESC
AVFoundation-based audio playback and microphone recording for the
xue_hua_audio Flutter plugin, shared between iOS and macOS.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_audio'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => 'matkurban@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'xue_hua_audio_darwin/Sources/xue_hua_audio_darwin/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
  s.resource_bundles = {
    'xue_hua_audio_darwin_privacy' => [
      'xue_hua_audio_darwin/Sources/xue_hua_audio_darwin/PrivacyInfo.xcprivacy'
    ]
  }
end
