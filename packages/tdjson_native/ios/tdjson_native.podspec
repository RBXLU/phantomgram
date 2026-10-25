# Embeds tdjson.xcframework (built by scripts/build_tdlib_ios.sh) into the app.
Pod::Spec.new do |s|
  s.name             = 'tdjson_native'
  s.version          = '0.1.0'
  s.summary          = 'TDLib JSON interface for Phantomgram.'
  s.description      = 'Prebuilt TDLib (libtdjson) packaged as a dynamic framework.'
  s.homepage         = 'https://github.com/tdlib/td'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Phantomgram' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.vendored_frameworks = 'Frameworks/tdjson.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
