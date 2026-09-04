#!/bin/bash
#
# make-dmg.sh — build both apps and package them into a drag-to-Applications DMG.
#
# The apps are ad-hoc signed (no Apple Developer account). The resulting DMG is
# NOT notarized, so users must approve each app once in System Settings ›
# Privacy & Security (see the "READ ME FIRST" inside the DMG). Building this on a
# Mac with an Apple Developer ID and notarizing the DMG would remove that step.
#
# Usage:  ./scripts/make-dmg.sh   ->   dist/TouchDeck.dmg

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST="$ROOT/dist"
say() { printf "\033[1;36m==>\033[0m %s\n" "$1"; }
die() { printf "\033[1;31mxx\033[0m %s\n" "$1" >&2; exit 1; }

# ---- Xcode -------------------------------------------------------------------
if xcodebuild -version >/dev/null 2>&1; then export DEVELOPER_DIR="$(xcode-select -p)"
elif [ -d "/Applications/Xcode.app/Contents/Developer" ]; then export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else die "Xcode not found. Install it from the App Store and launch it once."; fi
say "Using Xcode at: $DEVELOPER_DIR"

BUILD="$(mktemp -d)"; STAGE="$(mktemp -d)"
trap 'rm -rf "$BUILD" "$STAGE"' EXIT

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

# ---- Touch Up ----------------------------------------------------------------
say "Building Touch Up…"
xcodebuild -project "$ROOT/TouchUp/Touch Up.xcodeproj" -scheme "Touch Up" \
    -configuration Release -derivedDataPath "$BUILD/dd" \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" \
    build >"$BUILD/tu.log" 2>&1 || { tail -20 "$BUILD/tu.log"; die "Touch Up build failed."; }
TU="$BUILD/dd/Build/Products/Release/Touch Up.app"
codesign --force --sign - --timestamp=none "$TU/Contents/Frameworks/TouchUpCore.framework/Versions/A" >/dev/null 2>&1 || true
codesign --force --sign - --timestamp=none --entitlements "$BUILD/entitlements.plist" "$TU" >/dev/null 2>&1 || true

# ---- TouchKeys ---------------------------------------------------------------
say "Building TouchKeys…"
TK="$BUILD/TouchKeys.app"; mkdir -p "$TK/Contents/MacOS"
cat > "$TK/Contents/Info.plist" <<'PLIST'
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
xcrun swiftc -O -o "$TK/Contents/MacOS/TouchKeys" "$ROOT/TouchKeys/TouchKeys.swift" \
    -framework AppKit -framework ApplicationServices || die "TouchKeys build failed."
codesign --force --sign - --timestamp=none "$TK" >/dev/null 2>&1 || true

# ---- stage the DMG contents --------------------------------------------------
say "Staging DMG…"
ditto "$TU" "$STAGE/Touch Up.app"
ditto "$TK" "$STAGE/TouchKeys.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
TouchDeck — installation

1) Drag BOTH "Touch Up" and "TouchKeys" onto the Applications folder here.

2) First launch is blocked by macOS because these apps aren't notarized by
   Apple (this is a free open-source project). To allow them:
     • Double-click Touch Up. You'll see "cannot be opened."
     • Open System Settings › Privacy & Security, scroll down, and click
       "Open Anyway" next to Touch Up. Confirm.
     • Do the same for TouchKeys.
   You only do this once per app.

3) Grant Accessibility permission:
     System Settings › Privacy & Security › Accessibility
     → turn ON both "Touch Up" and "TouchKeys".
   Quit and reopen each app afterward.

4) Tell Touch Up which display is your touchscreen:
     Open Touch Up, find your touchscreen in the list, map it to the right
     display.

5) (Optional) To launch them automatically at login:
     System Settings › General › Login Items → add Touch Up and TouchKeys.

Full guide: https://github.com/whiteoakmedia/TouchDeck/blob/main/docs/SETUP.md
TXT

# ---- build the DMG -----------------------------------------------------------
say "Creating DMG…"
mkdir -p "$DIST"
rm -f "$DIST/TouchDeck.dmg"
hdiutil create -volname "TouchDeck" -srcfolder "$STAGE" -ov -format UDZO \
    "$DIST/TouchDeck.dmg" >/dev/null
say "Done: $DIST/TouchDeck.dmg"
ls -lh "$DIST/TouchDeck.dmg"
