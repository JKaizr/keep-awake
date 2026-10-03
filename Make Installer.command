#!/bin/bash
# Postaví instalační build/Awake-<verze>.dmg a ukáže ho ve Finderu.
cd "$(dirname "$0")"
mkdir -p build
bash make-dmg.sh 2>&1 | tee build/dmg.log
DMG=$(ls -t build/Awake-*.dmg 2>/dev/null | head -1)
if [[ -n "$DMG" ]]; then
  {
    echo; echo "--- kontrola ---"
    hdiutil verify "$DMG" 2>&1 | tail -1
    M=$(hdiutil attach -nobrowse -readonly -noverify "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF}')
    ls -la "$M"
    codesign -dv "$M/Awake.app" 2>&1 | grep -E 'Identifier|Format|Signature'
    lipo -archs "$M/Awake.app/Contents/MacOS/Awake"
    hdiutil detach -quiet "$M"
  } 2>&1 | tee -a build/dmg.log
  open -R "$DMG"
fi
