#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$task_root"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iPhone builds require macOS and Xcode. Run this script on a Mac." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Install Flutter and add its bin directory to PATH first." >&2
  exit 1
fi
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo "Select a full Xcode installation with the iOS SDK before building." >&2
  exit 1
fi

task_mode="${1:-prepare}"
case "$task_mode" in
  prepare)
    flutter pub get
    flutter build ios --config-only --no-codesign
    open ios/Runner.xcworkspace
    ;;
  check)
    flutter pub get
    flutter analyze
    flutter test
    flutter build ios --release --no-codesign
    ;;
  device)
    task_device="${2:-}"
    if [[ -z "$task_device" ]]; then
      echo "Usage: bash scripts/ios.sh device <iPhone ID from flutter devices>" >&2
      exit 1
    fi
    flutter pub get
    flutter run --release -d "$task_device"
    ;;
  sideload)
    flutter pub get
    flutter build ios --release --no-codesign
    task_app="$task_root/build/ios/iphoneos/Runner.app"
    if [[ ! -d "$task_app" ]]; then
      echo "The iOS build did not create Runner.app." >&2
      exit 1
    fi
    task_output="$task_root/build/ios/sideload"
    mkdir -p -- "$task_output"
    task_stage="$(mktemp -d "$task_output/package.XXXXXX")"
    mkdir -p -- "$task_stage/Payload"
    /usr/bin/ditto "$task_app" "$task_stage/Payload/Runner.app"
    /usr/bin/ditto -c -k --norsrc --keepParent \
      "$task_stage/Payload" "$task_output/berik-tulga-unsigned.ipa"
    (
      cd -- "$task_output"
      shasum -a 256 berik-tulga-unsigned.ipa > berik-tulga-unsigned.ipa.sha256
    )
    echo "IPA ready for signing with your own Apple ID on Windows:"
    echo "$task_output/berik-tulga-unsigned.ipa"
    ;;
  ipa)
    task_export="${2:-app-store}"
    case "$task_export" in
      app-store|ad-hoc|development|enterprise) ;;
      *) echo "Unknown export method: $task_export" >&2; exit 1 ;;
    esac
    flutter pub get
    flutter build ipa --release --export-method "$task_export"
    ;;
  *)
    echo "Usage: bash scripts/ios.sh {prepare|check|device <id>|sideload|ipa [export-method]}" >&2
    exit 1
    ;;
esac
