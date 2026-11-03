#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Compile no macOS.' >&2; exit 1; }
configuration="${1:-release}"
architecture="${2:-universal}"
[[ "$configuration" == release || "$configuration" == debug ]] || { echo 'Uso: build-app.sh [release|debug] [universal|native]' >&2; exit 1; }
case "$architecture" in
  universal) arch_flags=(--arch arm64 --arch x86_64); cc_arch=(-arch arm64 -arch x86_64) ;;
  native) arch_flags=(--arch "$(uname -m)"); cc_arch=(-arch "$(uname -m)") ;;
  *) echo 'Arquitetura inválida.' >&2; exit 1 ;;
esac
swift build -c "$configuration" "${arch_flags[@]}"
binary_dir="$(swift build -c "$configuration" "${arch_flags[@]}" --show-bin-path)"
app_dir="$PWD/dist/SQLGarden.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/SQLGarden" "$app_dir/Contents/MacOS/SQLGarden"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cc -std=c11 -mmacosx-version-min=14.0 "${cc_arch[@]}" -Wall -Wextra -Werror Sources/Launcher/main.c -o "$app_dir/Contents/MacOS/SQLGardenLauncher"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable SQLGardenLauncher' "$app_dir/Contents/Info.plist"
xcrun actool Resources/Assets.xcassets --compile "$app_dir/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 --target-device mac --app-icon AppIcon \
  --output-partial-info-plist "$PWD/.build/assets-info.plist" --output-format human-readable-text
# Keep the exact .icns files supplied by the author as persistent Finder icons.
cp Resources/AppIcon*.icns "$app_dir/Contents/Resources/"
cp INSTALACAO.md LICENSE "$app_dir/Contents/Resources/"
cp scripts/setup-mac.sh "$app_dir/Contents/Resources/Instalar Dependencias.command"
chmod +x "$app_dir/Contents/Resources/Instalar Dependencias.command"
codesign --force --sign - "$app_dir/Contents/MacOS/SQLGarden"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "App criado: $app_dir ($architecture). Assinatura ad hoc local."
