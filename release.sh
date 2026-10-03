#!/bin/bash
# Vydá novou verzi Awake.
#   bash release.sh 1.1
#
# 1. zkontroluje, že nemáš neuložené změny
# 2. nastaví verzi v Info.plist i v Xcode projektu
# 3. spustí testy, zbuildí a nainstaluje appku
# 4. zabalí build/Awake-1.1.zip
# 5. udělá commit „Release 1.1“ + tag v1.1 a pushne na GitHub
# 6. když máš GitHub CLI (gh), rovnou vytvoří GitHub Release se zipem
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Použití: bash release.sh 1.1"; exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION už existuje."; exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Máš necommitnuté změny. Nejdřív je commitni (git add -A && git commit -m \"…\")."; exit 1
fi
if ! grep -q "## $VERSION" CHANGELOG.md; then
  echo "⚠︎  V CHANGELOG.md chybí sekce '## $VERSION'. Doplň ji a commitni, pak spusť znovu."; exit 1
fi

BUILD_NUMBER="$(($(git rev-list --count HEAD) + 1))"
echo "→ Verze $VERSION (build $BUILD_NUMBER)"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Awake/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Awake/Info.plist
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g; s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" \
  Awake.xcodeproj/project.pbxproj

echo "→ Testy…"
bash "Run Tests.command" >/dev/null
if ! grep -q "ALL PASSED" test-results.txt; then
  cat test-results.txt
  git checkout -- Awake/Info.plist Awake.xcodeproj/project.pbxproj
  echo "✗ Testy neprošly, verze nevydána."; exit 1
fi
echo "✓ Testy prošly"

ZIP="build/Awake-$VERSION.zip"
ditto -c -k --keepParent build/Awake.app "$ZIP"

git add Awake/Info.plist Awake.xcodeproj/project.pbxproj
git commit -m "Release $VERSION"
git tag -a "v$VERSION" -m "Awake $VERSION"
git push
git push origin "v$VERSION"

if command -v gh >/dev/null 2>&1; then
  NOTES="$(awk "/^## $VERSION/{f=1;next} /^## /{f=0} f" CHANGELOG.md)"
  gh release create "v$VERSION" "$ZIP" --title "Awake $VERSION" --notes "$NOTES"
  echo "✓ GitHub Release v$VERSION vytvořen"
else
  echo "ℹ︎ GitHub CLI není nainstalované. Release vytvoř ručně na GitHubu (Releases → Draft a new release → tag v$VERSION) a přilož $ZIP."
fi
echo "✓ Hotovo: Awake $VERSION"
