#!/bin/bash
# TouchDeck uninstaller — removes both apps and their login items.
# Does NOT revoke the Accessibility permissions; remove those yourself in
# System Settings › Privacy & Security › Accessibility if you wish.
set -euo pipefail

say() { printf "\033[1;36m==>\033[0m %s\n" "$1"; }

say "Quitting apps…"
osascript -e 'tell application "Touch Up" to quit' 2>/dev/null || true
osascript -e 'tell application "TouchKeys" to quit' 2>/dev/null || true
pkill -f "/Applications/Touch Up.app/Contents/MacOS" 2>/dev/null || true
pkill -f "/Applications/TouchKeys.app/Contents/MacOS" 2>/dev/null || true
sleep 1

say "Removing login items…"
osascript >/dev/null 2>&1 <<'OSA' || true
tell application "System Events"
    delete (every login item whose path is "/Applications/Touch Up.app")
    delete (every login item whose path is "/Applications/TouchKeys.app")
end tell
OSA

say "Removing apps…"
rm -rf "/Applications/Touch Up.app" "/Applications/TouchKeys.app"

say "Done. TouchDeck removed."
