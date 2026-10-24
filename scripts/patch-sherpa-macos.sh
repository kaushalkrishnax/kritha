#!/usr/bin/env bash
# Workaround for Xcode error:
#   Multiple commands produce '.../include/module.modulemap'
# Caused by sherpa_onnx_macos and litertlm both shipping a top-level
# Headers/module.modulemap inside their macOS xcframeworks.
# Removing sherpa's module.modulemap avoids the output collision; the
# sherpa Dart/FFI side does not import the C module as a Swift module.
set -euo pipefail

SHERPA_PKG="$HOME/.pub-cache/hosted/pub.dev/sherpa_onnx_macos-1.13.8/macos/sherpa_onnx_macos/sherpa-onnx.xcframework"
MODULEMAP="$SHERPA_PKG/macos-arm64_x86_64/Headers/module.modulemap"

if [ -f "$MODULEMAP" ]; then
  rm -f "$MODULEMAP"
  echo "Removed conflicting module.modulemap from sherpa_onnx_macos."
else
  echo "No conflicting module.modulemap present (already patched)."
fi
