#!/bin/bash
cd "$(dirname "$0")"
bash build.sh install 2>&1 | tee build.log
echo
echo "--- Assertions od Awake ---"
pmset -g assertions | grep -A3 '(Awake)' || echo "(zatím žádné — appka je Vypnuto)"
