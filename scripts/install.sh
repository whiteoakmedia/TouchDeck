#!/bin/bash
#
# TouchDeck installer — builds both apps from source, signs them locally,
# installs to /Applications, and sets them to launch at login.
#
# Usage:  ./scripts/install.sh
#
# Requirements: Xcode (not just Command Line Tools) — the Touch Up driver is an
# Xcode project. If you only have Command Line Tools, install Xcode from the App
# Store first, launch it once, then re-run this script.

set -euo pipefail

# ---- locate ourselves --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPS="/Applications"

say()  { printf "\033[1;36m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$1"; }
die()  { printf "\033[1;31mxx\033[0m %s\n" "$1" >&2; exit 1; }

# ---- find a real Xcode -------------------------------------------------------
say "Checking for Xcode…"
XCODE_DEV=""
if xcodebuild -version >/dev/null 2>&1; then
    XCODE_DEV="$(xcode-select -p)"
elif [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    XCODE_DEV="/Applications/Xcode.app/Contents/Developer"
else
    # first Xcode we can find
    CAND="$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | head -1 || true)"
    [ -n "$CAND" ] && XCODE_DEV="$CAND"
fi
[ -n "$XCODE_DEV" ] || die "Xcode not found. Install Xcode from the App Store, launch it once, then re-run this script. (Command Line Tools alone cannot build the driver.)"
export DEVELOPER_DIR="$XCODE_DEV"
say "Using Xcode at: $DEVELOPER_DIR"

# ---- build the Touch Up driver ----------------------------------------------
say "Building the Touch Up driver (this takes a minute)…"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Ad-hoc signing ("-") works on any Mac with no developer account. We disable
# library validation so the ad-hoc-signed app can load its embedded framework.
cat > "$BUILD/entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.device.usb</key><true/>
    <key>com.apple.security.files.user-selected.read-only</key><true/>
    <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict>
</plist>
PLIST

xcodebuild -project "$ROOT/TouchUp/Touch Up.xcodeproj" \
    -scheme "Touch Up" -configuration Release \
    -derivedDataPath "$BUILD/dd" \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" \
    build >"$BUILD/touchup.log" 2>&1 \
  || { tail -20 "$BUILD/touchup.log"; die "Touch Up build failed (see log above)."; }

TU_SRC="$BUILD/dd/Build/Products/Release/Touch Up.app"
[ -d "$TU_SRC" ] || die "Build succeeded but app not found."

# Re-sign framework then app, ad-hoc, with the entitlements.
codesign --force --sign - --timestamp=none \
    "$TU_SRC/Contents/Frameworks/TouchUpCore.framework/Versions/A" >/dev/null 2>&1 || true
codesign --force --sign - --timestamp=none \
    --entitlements "$BUILD/entitlements.plist" "$TU_SRC" >/dev/null 2>&1 || true

# ---- build TouchKeys ---------------------------------------------------------
say "Building the TouchKeys on-screen keyboard…"
TK_APP="$BUILD/TouchKeys.app"
mkdir -p "$TK_APP/Contents/MacOS"
cat > "$TK_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.whiteoakmedia.touchkeys</string>
    <key>CFBundleName</key><string>TouchKeys</string>
    <key>CFBundleExecutable</key><string>TouchKeys</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
xcrun swiftc -O -o "$TK_APP/Contents/MacOS/TouchKeys" \
    "$ROOT/TouchKeys/TouchKeys.swift" \
    -framework AppKit -framework ApplicationServices \
  || die "TouchKeys build failed."
codesign --force --sign - --timestamp=none "$TK_APP" >/dev/null 2>&1 || true

# ---- install -----------------------------------------------------------------
say "Installing to $APPS…"
for pair in "$TU_SRC|$APPS/Touch Up.app" "$TK_APP|$APPS/TouchKeys.app"; do
    src="${pair%|*}"; dst="${pair#*|}"
    [ -d "$dst" ] && rm -rf "$dst"
    ditto "$src" "$dst"
done

# ---- login items -------------------------------------------------------------
say "Setting both apps to launch at login…"
osascript >/dev/null 2>&1 <<'OSA' || warn "Could not add login items automatically — add them yourself in System Settings › General › Login Items."
tell application "System Events"
    if not (exists login item "Touch Up") then make login item at end with properties {path:"/Applications/Touch Up.app", hidden:false}
    if not (exists login item "TouchKeys") then make login item at end with properties {path:"/Applications/TouchKeys.app", hidden:false}
end tell
OSA

# ---- launch + hand off to setup ---------------------------------------------
open "$APPS/Touch Up.app" || true
open "$APPS/TouchKeys.app" || true

cat <<'DONE'

────────────────────────────────────────────────────────────
  TouchDeck is installed.  Two quick manual steps remain
  (macOS requires YOU to grant these — no app can self-grant):

  1) Grant Accessibility permission to BOTH apps:
       System Settings › Privacy & Security › Accessibility
       → turn on "Touch Up" and "TouchKeys"
     Opening that pane now…

  2) Tell Touch Up which display your touchscreen is:
       Open Touch Up, find your touchscreen in the list,
       and map it to the correct display.

  Full walkthrough: docs/SETUP.md
────────────────────────────────────────────────────────────
DONE

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
