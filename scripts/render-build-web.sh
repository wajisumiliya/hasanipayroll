#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_version=3.47.0
flutter_sdk_dir="${FLUTTER_SDK_DIR:-/tmp/hasani-flutter-${flutter_version}}"
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$flutter_sdk_dir/bin/flutter" ]; then
    git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$flutter_sdk_dir"
  fi
  export PATH="$flutter_sdk_dir/bin:$PATH"
fi
flutter config --enable-web --no-analytics
flutter pub get --enforce-lockfile
flutter build web --release --no-pub \
  --dart-define="API_BASE_URL=${API_BASE_URL:-https://hasaniworkhub.onrender.com}"
test -s build/web/main.dart.js
