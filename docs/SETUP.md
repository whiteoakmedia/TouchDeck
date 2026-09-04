# TouchDeck setup walkthrough

This is the step-by-step version of the quick setup in the
[README](../README.md). Follow it once, per Mac.

---

## Before you start

- Plug your touchscreen into the Mac by **both** cables it needs:
  - the **video** cable (HDMI / DisplayPort / USB-C) so the Mac shows a picture,
  - **and** the **USB** cable that carries touch data. This is the one people
    forget. A touchscreen connected by video only will display an image but
    send no touches.
- Make sure you have **Xcode** installed (Mac App Store) and have launched it at
  least once. Command Line Tools alone can't build the driver.

---

## Step 1 — Install

```bash
git clone https://github.com/whiteoakmedia/TouchDeck.git
cd TouchDeck
./scripts/install.sh
```

You'll see it build the driver, build the keyboard, install both to
`/Applications`, and open System Settings. If the build stops with
*"Xcode not found,"* install/launch Xcode and run the script again.

---

## Step 2 — Grant Accessibility permission

Both apps turn your touches and key taps into real input events. macOS requires
your explicit permission for that.

1. The installer opens **System Settings › Privacy & Security › Accessibility**.
   (To open it yourself: Apple menu › System Settings › Privacy & Security ›
   Accessibility.)
2. Turn **on** the toggles for **Touch Up** and **TouchKeys**.
   - If they aren't in the list yet, launch each app once (`/Applications`) and
     they'll appear.
3. Quit and reopen each app after granting, so it picks up the permission.

**How to tell it worked:** touch the screen — the cursor should move *and*
tapping should click. If the cursor moves but nothing clicks, Accessibility is
not actually on for Touch Up.

---

## Step 3 — Map your touchscreen to its display

This is the "pick the monitor" step. It tells Touch Up which physical screen the
glass corresponds to, so touches land in the right place — essential when you
have more than one monitor.

1. Open **Touch Up** (menu-bar icon or `/Applications/Touch Up.app`).
2. Find the **digitizer list**. Each connected touchscreen appears as a row,
   usually named after the panel hardware (for example
   *"LGDisplay Incell Touch"* — many touch monitors report their internal panel
   name, which may differ from the brand on the bezel).
3. For your touchscreen's row, choose the **display** it should control from the
   dropdown.
4. Test: touch the four corners of the glass. The cursor should reach each
   corner of that same screen. If it lands on the wrong monitor or is offset,
   return here and change the mapping.

> **Multi-monitor / ProPresenter tip:** map the touchscreen to the display you
> actually stand at. Leave your projector/output display unmapped so touches
> never wander onto it.

---

## Step 4 — Learn the gestures

| Gesture | Action |
| --- | --- |
| Tap | Click |
| Tap-hold, then move | Drag |
| One-finger flick | Scroll |
| Two-finger pinch | Zoom |
| Two-finger tap | Right-click |
| Three-finger swipe up | Mission Control |
| Three-finger swipe down | App Exposé |
| Three-finger swipe left / right | Switch Spaces |
| Three-finger tap | Previous app |
| Four-finger pinch in | Quit focused app |

For the Spaces swipes to work, keep **System Settings › Keyboard › Keyboard
Shortcuts › Mission Control › "Move left/right a space"** enabled (they're on by
default).

---

## Step 5 — On-screen keyboard

- Tap into any text field — the keyboard fades in at the bottom of that screen.
- Use the **⌨ menu-bar icon** to keep it shown, return to auto mode, or quit.
- **Spotlight is the one place it can't type** (Spotlight dismisses on any
  outside tap). Use an app's own search box instead.

---

## Troubleshooting

**Cursor moves but taps don't click**
→ Accessibility permission isn't actually on for Touch Up. Re-check Step 2, then
quit and reopen Touch Up.

**Touches land on the wrong monitor or are offset**
→ Redo Step 3 and map the touchscreen to the correct display.

**Nothing happens at all when I touch**
→ Confirm the touchscreen's **USB** cable is connected (not just video). Then
confirm Touch Up is running (menu-bar icon).

**Keyboard doesn't appear in a specific app**
→ That app may not expose its text fields to macOS's accessibility API. Use the
menu-bar **⌨ › Keep Keyboard Shown** as a fallback.

**Three-finger swipes do nothing**
→ Make sure the Mission Control keyboard shortcuts (Ctrl+arrows) are enabled in
System Settings › Keyboard › Keyboard Shortcuts › Mission Control.

**A gesture feels too sensitive or not sensitive enough**
→ The thresholds are named constants in
`TouchUp/TouchUpCore/TUCTouchInputManager.m` (search for `Threshold`, `Slop`,
`Spread`). Change, rebuild with `./scripts/install.sh`.
