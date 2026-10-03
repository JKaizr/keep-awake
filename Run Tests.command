#!/bin/bash
# Builds + installs Awake, then runs the functional self-test against the real
# macOS power-management API. Results are written to test-results.txt.
cd "$(dirname "$0")"
OUT=test-results.txt
BIN=/Applications/Awake.app/Contents/MacOS/Awake

{
  echo "Awake test run — $(date '+%Y-%m-%d %H:%M:%S') — macOS $(sw_vers -productVersion)"
  echo
  if ! bash build.sh install > build.log 2>&1; then
    echo "✗ BUILD FAILED"; cat build.log; exit 1
  fi
  echo "✓ build + install OK"
  echo
  "$BIN" --selftest
  echo "selftest exit code: $?"
  echo
  echo "--- Quit while active ---"
  "$BIN" --selftest --exit-while-active > /dev/null 2>&1
  sleep 1
  if pmset -g assertions | grep -q '(Awake)'; then
    echo "✗ assertions still present after the process exited:"
    pmset -g assertions | grep -A3 '(Awake)'
  else
    echo "✓ process exited while active → macOS released all its assertions"
  fi
  echo
  echo "--- Menu bar app running? ---"
  pgrep -x Awake >/dev/null && echo "✓ Awake.app is running in the menu bar" || echo "✗ Awake.app not running"
} > "$OUT" 2>&1

cat "$OUT"
