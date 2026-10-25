#!/usr/bin/env bash
# Builds libtdjson.so for Linux x86_64/arm64 and puts it where the
# tdjson_native plugin bundles it from.
#
# Needs: git cmake ninja-build gperf clang (or g++) zlib1g-dev libssl-dev
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMMIT=${TDLIB_COMMIT:-$(cat "$ROOT/scripts/TDLIB_COMMIT")}
WORK=${TDLIB_WORK:-$ROOT/.tdlib}
OUT=$ROOT/packages/tdjson_native/prebuilt/linux
JOBS=${JOBS:-$(nproc)}

mkdir -p "$WORK"
if [ ! -d "$WORK/td/.git" ]; then
  git clone https://github.com/tdlib/td.git "$WORK/td"
fi
git -C "$WORK/td" fetch --depth 1 origin "$COMMIT" 2>/dev/null || git -C "$WORK/td" fetch origin
git -C "$WORK/td" checkout --quiet "$COMMIT"

export CC=${CC:-clang} CXX=${CXX:-clang++}
cmake -S "$WORK/td" -B "$WORK/build-linux" -G Ninja -DCMAKE_BUILD_TYPE=Release
# TDLib is heavy on RAM (~1.5 GB per job); lower JOBS on small machines.
cmake --build "$WORK/build-linux" --target tdjson -j "$JOBS"

mkdir -p "$OUT"
lib=$(find "$WORK/build-linux" -maxdepth 1 -name 'libtdjson.so.*' -type f | head -n1)
cp "$lib" "$OUT/libtdjson.so"
strip --strip-unneeded "$OUT/libtdjson.so"
echo "OK: $OUT/libtdjson.so ($(du -h "$OUT/libtdjson.so" | cut -f1))"
