#!/usr/bin/env bash
#
# 編譯並組成 Babos.app，然後開起來。
#
#   ./build.sh          編譯 → 打包 → 執行
#   ./build.sh --norun  只編譯打包
#
# 建置產物刻意放在 ~/.cache 底下。這個專案在 ~/Desktop，而 Desktop 在
# iCloud 的 File Provider 管理下——生成物留在那裡的話，剛做好的 .app 會被
# 同步機制加上 com.apple.FinderInfo，codesign 直接拒絕簽章。
# HTML 版的 Babos 為了這件事被卡了三次才查出來。
set -euo pipefail

cd "$(dirname "$0")"

SCRATCH="$HOME/.cache/babos-swift-build"
APP="$SCRATCH/Babos.app"

swift build -c release --scratch-path "$SCRATCH"

BIN="$SCRATCH/release/Babos"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
cp "$BIN" "$APP/Contents/MacOS/Babos"

# 同梱フォント。Info.plist の ATSApplicationFontsPath がこのフォルダを指すので、
# 起動時に macOS が勝手に登録してくれる（自前で CTFontManager を叩く必要はない）。
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"

# アイコン。HTML 版と同じものを使う
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Info.plist が無いと Dock に出ない、メニューバーも壊れる。
# LSUIElement を入れないこと（入れると通常のウィンドウアプリにならない）。
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>Babos</string>
  <key>CFBundleDisplayName</key>       <string>Babos</string>
  <key>CFBundleExecutable</key>        <string>Babos</string>
  <key>CFBundleIdentifier</key>        <string>com.shihbo.babos-swift</string>
  <key>CFBundleVersion</key>           <string>0.2.2</string>
  <key>CFBundleShortVersionString</key><string>0.2.2</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>LSMinimumSystemVersion</key>    <string>14.0</string>
  <key>ATSApplicationFontsPath</key>   <string>Fonts</string>
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" 2>/dev/null || true

echo "→ $APP"

if [ "${1:-}" != "--norun" ]; then
  pkill -f "Babos.app/Contents/MacOS/Babos" 2>/dev/null || true
  sleep 0.5
  open "$APP"
fi
