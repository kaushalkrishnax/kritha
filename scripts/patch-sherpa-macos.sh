#!/usr/bin/env bash
# Workaround for Xcode error:
#   Multiple commands produce '.../include/module.modulemap'
# Caused by sherpa_onnx_macos and litertlm both shipping a top-level
# Headers/module.modulemap inside their macOS xcframeworks.
# Removing sherpa's module.modulemap avoids the output collision; the
# sherpa Dart/FFI side does not import the C module as a Swift module.
set -euo pipefail

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
COUNT=0

shopt -s nullglob
for map in "$PUB_CACHE_DIR"/hosted/pub.dev/sherpa_onnx_macos*/macos/sherpa_onnx_macos/sherpa-onnx.xcframework/*/Headers/module.modulemap; do
  if [ -f "$map" ]; then
    rm -f "$map"
    echo "Removed conflicting module.modulemap: $map"
    COUNT=$((COUNT + 1))
  fi
done

if [ "$COUNT" -gt 0 ]; then
  echo "Successfully patched $COUNT module.modulemap file(s)."
else
  echo "No conflicting module.modulemap present (already patched)."
fi
