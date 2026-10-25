#!/usr/bin/env bash
# Builds tdjson.xcframework (iPhone + simulator) on macOS and puts it where
# the tdjson_native podspec embeds it from.
#
# Needs: Xcode, `brew install gperf cmake coreutils`
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMMIT=${TDLIB_COMMIT:-$(cat "$ROOT/scripts/TDLIB_COMMIT")}
WORK=${TDLIB_WORK:-$ROOT/.tdlib}
OUT=$ROOT/packages/tdjson_native/ios/Frameworks
MIN_IOS=15.0
JOBS=${JOBS:-$(sysctl -n hw.ncpu)}
TD=$WORK/td

mkdir -p "$WORK"
if [ ! -d "$TD/.git" ]; then
  git clone https://github.com/tdlib/td.git "$TD"
fi
git -C "$TD" fetch --depth 1 origin "$COMMIT" 2>/dev/null || git -C "$TD" fetch origin
git -C "$TD" checkout --quiet "$COMMIT"

# 1. Generated sources come from a native (macOS) build.
cmake -S "$TD" -B "$WORK/native-build" -DTD_GENERATE_SOURCE_FILES=ON
cmake --build "$WORK/native-build" -j "$JOBS"

# 2. OpenSSL for iOS only (TDLib's script builds every Apple platform).
pushd "$TD/example/ios" >/dev/null
if [ ! -d third_party/openssl/iOS ] || [ ! -d third_party/openssl/iOS-simulator ]; then
  sed -i '' 's/^platforms=.*/platforms="iOS"/' build-openssl.sh
  ./build-openssl.sh
  git checkout -- build-openssl.sh
fi
popd >/dev/null

# 3. libtdjson.dylib per platform, wrapped into tdjson.framework.
frameworks=()
for platform in OS SIMULATOR; do
  name=iOS; [ "$platform" = SIMULATOR ] && name=iOS-simulator
  ssl=$TD/example/ios/third_party/openssl/$name
  build=$WORK/build-ios-$platform
  cmake -S "$TD" -B "$build" \
    -DCMAKE_TOOLCHAIN_FILE="$TD/CMake/iOS.cmake" \
    -DIOS_PLATFORM="$platform" \
    -DIOS_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DOPENSSL_FOUND=1 \
    -DOPENSSL_CRYPTO_LIBRARY="$ssl/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="$ssl/lib/libssl.a" \
    -DOPENSSL_INCLUDE_DIR="$ssl/include" \
    -DOPENSSL_LIBRARIES="$ssl/lib/libcrypto.a;$ssl/lib/libssl.a"
  ZERO_AR_DATE=1 cmake --build "$build" --target tdjson -j "$JOBS"

  dylib=$(find "$build" -maxdepth 1 -name 'libtdjson.*.dylib' -type f | head -n1)
  fw=$WORK/fw-$platform/tdjson.framework
  rm -rf "$fw" && mkdir -p "$fw"
  cp "$dylib" "$fw/tdjson"
  install_name_tool -id @rpath/tdjson.framework/tdjson "$fw/tdjson"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>tdjson</string>
  <key>CFBundleIdentifier</key><string>org.tdlib.tdjson</string>
  <key>CFBundleName</key><string>tdjson</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
  frameworks+=(-framework "$fw")
done

rm -rf "$OUT/tdjson.xcframework"
mkdir -p "$OUT"
xcodebuild -create-xcframework "${frameworks[@]}" -output "$OUT/tdjson.xcframework"
echo "OK: $OUT/tdjson.xcframework"
