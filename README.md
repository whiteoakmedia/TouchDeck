# TouchDeck

**Turn any USB touchscreen into a first-class Mac touch console** — reliable
tap-to-click, multi-touch gestures for switching windows, and an on-screen
keyboard that appears when you tap into a text field.

TouchDeck bundles two apps:

- **Touch Up** — a user-space touchscreen driver (an enhanced fork of
  [shueber/Touch-Up](https://github.com/shueber/Touch-Up)) that turns raw USB
  HID touch data into real mouse events: tap, drag, scroll, pinch-to-zoom.
- **TouchKeys** — a lightweight on-screen keyboard that auto-shows when a text
  field has focus and types into whatever app you're using.

> Built for a church production Mac driving ProPresenter from a touchscreen,
> but it works for any touchscreen-on-Mac setup: kiosks, digital signage,
> lecterns, accessibility stations.

---

## What you get

| Gesture | What it does |
| --- | --- |
| Tap | Click |
| Tap and hold, then move | Drag (move windows, drag files, work sliders) |
| Flick one finger | Scroll |
| Pinch two fingers | Zoom |
| Two-finger tap | Right-click |
| **Three-finger swipe up** | Mission Control |
| **Three-finger swipe down** | App Exposé |
| **Three-finger swipe left / right** | Switch Spaces |
| **Three-finger tap** | Switch to previous app |
| **Four-finger pinch in** | Quit the focused app |
| Tap into a text field | On-screen keyboard appears |

Gesture thresholds are tuned for real fingers on real panels — see
[What's different from upstream Touch-Up](#whats-different-from-upstream-touch-up).

---

## Requirements

- macOS 13 (Ventura) or later
- A USB touchscreen that reports standard HID digitizer data (most do — if it
  works on Windows without a driver, it will work here)
- **Xcode** (from the Mac App Store) to build. Command Line Tools alone are not
  enough — the driver is an Xcode project. Install Xcode, launch it once, then
  run the installer.

> **Why do I have to build it myself?** TouchDeck ships as source, signed
> locally on your machine. It is **not** notarized by Apple (that needs a paid
> Apple Developer account). Building locally is the friction-free way to get an
> app macOS will trust. See [Distribution & signing](#distribution--signing).

---

## Install

```bash
git clone https://github.com/whiteoakmedia/TouchDeck.git
cd TouchDeck
./scripts/install.sh
```

The installer builds both apps, signs them locally, installs them to
`/Applications`, sets them to launch at login, and opens the two System Settings
panes you need. Then follow the two manual steps below.

To remove everything later: `./scripts/uninstall.sh`

---

## First-run setup (the two things only you can do)

macOS will not let any app grant itself these — you have to click them once.

### 1. Grant Accessibility permission

Both apps inject input events, which macOS gates behind Accessibility.

1. Open **System Settings › Privacy & Security › Accessibility**
   (the installer opens this for you).
2. Turn **on** the switches for **Touch Up** and **TouchKeys**.
3. If an app was running, quit and reopen it so the grant takes effect.

If clicks or keystrokes do nothing, this is almost always the cause — the app
runs but its events are silently dropped until Accessibility is granted.

### 2. Pick your touchscreen's display

Touch Up needs to know which monitor is the touchscreen, so a touch at the
top-left of the glass lands at the top-left of that screen.

1. Open **Touch Up** (menu-bar icon, or from `/Applications`).
2. You'll see a list of connected digitizers. Find your touchscreen — it's
   usually named after the panel (e.g. *"LGDisplay Incell Touch"*).
3. Map it to the correct display from the dropdown.
4. If touches land in the wrong place or on the wrong monitor, come back here
   and re-map — this is the fix for a multi-monitor setup.

Full illustrated walkthrough: **[docs/SETUP.md](docs/SETUP.md)**.

---

## Using the on-screen keyboard

- Tap into any text field and the keyboard fades in at the bottom of that
  screen. Tap elsewhere and it fades away.
- The **⌨ menu-bar icon** lets you keep it shown (pin), return to auto mode, or
  quit.
- **⇧** is a one-shot shift (like iPadOS); **#+=** switches to numbers/symbols;
  **▼** hides the keyboard until the next time you focus a text field.

**Known limits**

- **Spotlight doesn't work** with it — Spotlight closes the instant you tap
  anything outside its own window, including the keyboard. Use in-app search
  fields instead. (Apple's own keyboard gets a private exemption; third-party
  ones can't.)
- Some apps that draw custom text views may not report their fields through the
  accessibility API. Chromium/Electron apps (Chrome, VS Code, Slack, etc.) are
  handled specially and work.

---

## What's different from upstream Touch-Up

TouchDeck's driver is a fork of [shueber/Touch-Up](https://github.com/shueber/Touch-Up)
with these changes, developed and tuned against a real touchscreen:

- **Reliable tap-to-click.** Upstream disqualified a tap if the finger moved
  more than 0.1 mm between frames — impossible for a real fingertip, so taps
  often never became clicks. Replaced with a cumulative slop zone from the touch
  origin.
- **Correct rapid-tap click counting.** Fixed a comparison bug that made quick
  successive taps escalate into double/triple-clicks.
- **Jitter-tolerant hold-and-drag**, measured from where the finger landed
  rather than a per-frame stationary flag.
- **Three-finger gestures** — swipe up/down/left/right and tap, mapped to
  Mission Control, App Exposé, Spaces, and app switching.
- **Four-finger pinch-in** to quit the focused app.

These fixes and features are candidates to contribute back upstream.

---

## Distribution & signing

TouchDeck is **built and signed locally** on each machine with an ad-hoc
signature. That means:

- No Apple Developer account required, no cost.
- The app macOS runs is one it saw compiled on your Mac, so Gatekeeper trusts
  it and the Accessibility grant is stable.
- The trade-off: there's no downloadable pre-notarized `.app`. Everyone builds
  from source with the one-line installer.

If this project later gets an Apple Developer ID, a notarized `.dmg` release
would make installation a drag-and-drop with no Xcode needed. Contributions
welcome.

---

## Credits & license

- Original **Touch-Up** driver © Sebastian Hueber —
  <https://github.com/shueber/Touch-Up> (MIT).
- TouchDeck modifications, gestures, and the TouchKeys keyboard © White Oak
  Media.

Released under the **MIT License** — see [LICENSE](LICENSE).
