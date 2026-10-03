#!/bin/bash
# Builds Awake.app without opening Xcode.
#   bash build.sh            → build into ./build and launch
#   bash build.sh install    → build, copy to /Applications and launch
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Chybí Swift toolchain. Nainstaluj Xcode z App Store, nebo spusť: xcode-select --install"
  exit 1
fi

APP="build/Awake.app"
ARCH="$(uname -m)"
SDK="$(xcrun --show-sdk-path --sdk macosx)"

echo "→ Kompiluji ($ARCH)…"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  -sdk "$SDK" \
  Awake/*.swift \
  -o "$APP/Contents/MacOS/Awake"

cp Awake/Info.plist "$APP/Contents/Info.plist"
cp Awake/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ Podepisuji (ad-hoc, App Sandbox)…"
codesign --force --options runtime \
  --entitlements Awake/Awake.entitlements \
  --sign - "$APP"

pkill -x Awake 2>/dev/null || true
touch "$APP"  # refresh Finder/Dock icon cache

if [[ "${1:-}" == "install" ]]; then
  rm -rf /Applications/Awake.app
  cp -R "$APP" /Applications/
  echo "✓ Nainstalováno do /Applications/Awake.app"
  open /Applications/Awake.app
else
  echo "✓ Hotovo: $APP"
  open "$APP"
fi
