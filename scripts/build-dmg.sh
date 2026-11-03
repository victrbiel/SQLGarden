#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_dir="$PWD/dist/SQLGarden.app"
[[ -d "$app_dir" ]] || { echo 'Compile primeiro: bash scripts/build-app.sh release universal' >&2; exit 1; }
codesign --verify --deep --strict "$app_dir"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")
staging=$(mktemp -d "${TMPDIR:-/tmp/}sqlgarden-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app_dir" "$staging/SQLGarden.app"
ln -s /Applications "$staging/Applications"
cp INSTALACAO.md LICENSE "$staging/"
cp scripts/setup-mac.sh "$staging/Instalar Dependencias.command"
cp scripts/setup-express.sh "$staging/Criar SQL Server Express.command"
chmod +x "$staging/"*.command
cp Resources/AppIcon.icns "$staging/.VolumeIcon.icns"
xcrun SetFile -a C "$staging" 2>/dev/null || true
# Build a new image; do not silently overwrite an existing release.
output="$PWD/dist/SQLGarden-$version-Universal.dmg"
[[ ! -e "$output" ]] || { echo "A imagem já existe: $output. Preserve-a ou remova somente esse artefato antes de repetir." >&2; exit 1; }
hdiutil create -volname "SQLGarden $version" -srcfolder "$staging" -fs HFS+ -format UDZO "$output"
hdiutil verify "$output"
echo "DMG criado e verificado: $output"
