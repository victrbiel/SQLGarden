#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "O aplicativo precisa ser compilado no macOS." >&2; exit 1
fi
configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
  echo "Uso: bash scripts/build-app.sh [release|debug]" >&2; exit 1
fi
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$PWD/dist/SQLGarden.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/SQLGarden" "$app_dir/Contents/MacOS/SQLGarden"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
# Finder does not inherit a Terminal environment. Keep the ODBC/OpenSSL
# workaround local to the app instead of relinking Homebrew globally.
cc -std=c11 -mmacosx-version-min=14.0 -Wall -Wextra -Werror Sources/Launcher/main.c -o "$app_dir/Contents/MacOS/SQLGardenLauncher"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable SQLGardenLauncher' "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir/Contents/MacOS/SQLGarden"
codesign --force --sign - "$app_dir"
echo "App compilado: $app_dir"
echo "Para abrir: open dist/SQLGarden.app"
