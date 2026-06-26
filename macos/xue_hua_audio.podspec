#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_audio.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_audio'
  s.version          = '1.0.1'
  s.summary          = 'Cross-platform Flutter FFI audio plugin.'
  s.description      = <<-DESC
Cross-platform Flutter FFI audio plugin powered by Rust/rodio.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_audio'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => 'https://github.com/Matkurban' }
  s.module_name      = 'xue_hua_audio'

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument is relative path to the `rust` folder, second is name of rust library
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust xue_hua_audio',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    # Let XCode know that the static library referenced in -force_load below is
    # created by this build step.
    :output_files => ["${PODS_CONFIGURATION_BUILD_DIR}/xue_hua_audio/libxue_hua_audio.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-framework AudioToolbox -framework CoreAudio -framework AudioUnit -framework CoreFoundation -force_load ${PODS_CONFIGURATION_BUILD_DIR}/xue_hua_audio/libxue_hua_audio.a',
  }
end
