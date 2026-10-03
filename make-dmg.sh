#!/bin/bash
# Builds a distributable installer: build/Awake-<verze>.dmg
#
#   bash make-dmg.sh
#
# - universal binary (Apple Silicon + Intel), macOS 13+
# - drag-to-Applications window with background
# - signing:
#     * default: ad-hoc. Friends must allow the app once in
#       System Settings → Privacy & Security → Open Anyway.
#     * with an Apple Developer ID (99 USD/yr) and notarization the app opens
#       without any warning:
#         DEVELOPER_ID="Developer ID Application: Jiri Kaizr (TEAMID)" \
#         NOTARY_PROFILE="awake-notary" bash make-dmg.sh
#       (create the profile once: xcrun notarytool store-credentials awake-notary)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Awake/Info.plist)"
SIGN_ID="${DEVELOPER_ID:--}"
WORK="build/dmg"
APP="$WORK/Awake.app"
DMG="build/Awake-$VERSION.dmg"
SDK="$(xcrun --show-sdk-path --sdk macosx)"

echo "→ Awake $VERSION — universal build"
rm -rf "$WORK" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WORK/obj"

for ARCH in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -target "${ARCH}-apple-macos13.0" -sdk "$SDK" \
    Awake/*.swift -o "$WORK/obj/Awake-$ARCH"
done
lipo -create "$WORK/obj/Awake-arm64" "$WORK/obj/Awake-x86_64" -output "$APP/Contents/MacOS/Awake"
rm -rf "$WORK/obj"

cp Awake/Info.plist "$APP/Contents/Info.plist"
cp Awake/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ Podepisuji ($([[ "$SIGN_ID" == "-" ]] && echo ad-hoc || echo "$SIGN_ID"))"
TS_FLAG=()
[[ "$SIGN_ID" != "-" ]] && TS_FLAG=(--timestamp)
codesign --force --options runtime ${TS_FLAG[@]+"${TS_FLAG[@]}"} \
  --entitlements Awake/Awake.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"

echo "→ Skládám DMG…"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Aplikace"
if command -v tiffutil >/dev/null && [[ -f dmg/background@2x.png ]]; then
  tiffutil -cathidpicheck dmg/background.png dmg/background@2x.png -out "$STAGE/.background/background.tiff" >/dev/null 2>&1
  BG="background.tiff"
else
  cp dmg/background.png "$STAGE/.background/background.png"
  BG="background.png"
fi

RW="$WORK/rw.dmg"
hdiutil create -quiet -volname "Awake $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
MOUNT_DIR="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')"
VOL_NAME="$(basename "$MOUNT_DIR")"

# Window layout (needs Finder automation permission the first time; skipped if denied).
osascript <<EOF || echo "ℹ︎ Rozvržení okna se nepodařilo nastavit (chybí povolení pro Finder) — DMG funguje i tak."
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 562}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:$BG"
    set position of item "Awake.app" of container window to {160, 200}
    set position of item "Aplikace" of container window to {480, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

# Volume icon = app icon
cp Awake/AppIcon.icns "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR" 2>/dev/null || true

sync
hdiutil detach -quiet "$MOUNT_DIR"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW"

if [[ "$SIGN_ID" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "→ Notarizace (pár minut)…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

echo
echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
echo "  architektury: $(lipo -archs "$APP/Contents/MacOS/Awake")"
