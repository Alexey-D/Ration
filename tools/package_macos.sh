#!/usr/bin/env bash
# Builds the macOS release and packs it into dist/Ration-<version>-macos.dmg.
# Run on a Mac (Xcode + Flutter) from the project root:  bash tools/package_macos.sh
# Requires macOS: Apple allows building macOS apps only on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml)

if [[ "${1:-}" != "--skip-build" ]]; then
  flutter build macos --release
fi

app="build/macos/Build/Products/Release/Ration.app"
[[ -d "$app" ]] || { echo "Not found: $app" >&2; exit 1; }

mkdir -p dist
staging=$(mktemp -d)
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"   # drag-and-drop install
cp tools/dist_readme_macos.txt "$staging/README.txt"

dmg="dist/Ration-$version-macos.dmg"
rm -f "$dmg"
hdiutil create -volname "Рацион" -srcfolder "$staging" -fs HFS+ -format UDZO "$dmg"
rm -rf "$staging"

echo "DMG: $dmg ($(du -h "$dmg" | cut -f1))"
