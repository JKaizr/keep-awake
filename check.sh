#!/bin/bash
# Shows which power assertions Awake currently holds (live, refreshes every 2 s).
#   bash check.sh        → watch continuously (Ctrl+C to stop)
#   bash check.sh once   → print once
show() {
  clear 2>/dev/null || true
  date '+%H:%M:%S'
  echo "--- Awake assertions ---"
  out="$(pmset -g assertions | grep -A3 '(Awake)' || true)"
  if [[ -z "$out" ]]; then echo "(žádné — Mac se řídí systémovým nastavením)"; else echo "$out"; fi
  echo
  echo "--- Souhrn systému ---"
  pmset -g assertions | grep -E '^\s+(PreventUserIdleSystemSleep|PreventUserIdleDisplaySleep)\s'
}
if [[ "${1:-}" == "once" ]]; then show; exit 0; fi
while true; do show; sleep 2; done
