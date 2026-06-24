#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Snapix dev runner — reads secrets from dart_defines.json
# Usage:
#   ./run_dev.sh                          # run on connected device
#   ./run_dev.sh -d "iPhone 17 Pro Max"  # specify simulator
#   ./run_dev.sh --release                # release mode
#   ./run_dev.sh --profile               # profile mode
# ─────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

DEFINES_FILE="dart_defines.json"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "❌  $DEFINES_FILE not found."
  echo "   Copy dart_defines.json.example to dart_defines.json and fill in your secrets."
  exit 1
fi

echo "🚀 flutter run --dart-define-from-file=$DEFINES_FILE $*"
flutter run --dart-define-from-file="$DEFINES_FILE" "$@"
