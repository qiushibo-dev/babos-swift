#!/usr/bin/env bash
#
# 配布用の dmg を作る。
#
#   ./package.sh            バージョンは Info.plist から拾う
#   ./package.sh 0.1.0      明示する
#
# 出来上がりは ~/.cache/babos-swift-build/Babos_<version>.dmg
set -euo pipefail

cd "$(dirname "$0")"

SCRATCH="$HOME/.cache/babos-swift-build"
APP="$SCRATCH/Babos.app"

# まず確実に最新を組む（起動はしない）
./build.sh --norun

VERSION="${1:-$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)}"
DMG="$SCRATCH/Babos_${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# dmg の中身：アプリ本体と、ドラッグ先としての Applications への別名
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "Babos" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" > /dev/null

echo "→ $DMG"
echo "   $(du -h "$DMG" | cut -f1)"
echo ""
echo "インストールする側は、初回だけ隔離属性を外す必要がある："
echo "   xattr -dr com.apple.quarantine /Applications/Babos.app"
