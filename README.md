# univ-remote-for-logi

Bring your Logitech MX Master gestures back when the mouse is being forwarded
to another Mac via **Universal Control**.

## The Problem

When you use Universal Control to share a Logitech mouse between two Macs, the
receiving Mac does not see the physical USB/Bluetooth device — it only sees
synthesized `CGEvent`s that Apple's WindowServer generates from the forwarded
motion/clicks. Because of that:

- **Logi Options+ on the receiving Mac cannot bind to the mouse** (there is no
  HID device with a matching VID/PID to attach to).
- SteerMouse, USB Overdrive, Karabiner-Elements, and any other IOKit-level
  tool all fail for the same reason.
- The thumb gesture button, horizontal tilt, and other "extra" inputs become
  dead weight on the receiving Mac.

The only layer where these events are visible is `CGEventTap`. This project
sits at that layer via Hammerspoon and re-implements the most-missed gestures.

## What It Does

MX Master thumb gesture button (button 5):

| Input            | Action                |
| ---------------- | --------------------- |
| click (no drag)  | Mission Control       |
| drag **left**    | Desktop Right         |
| drag **right**   | Desktop Left          |
| drag **up**      | Launchpad             |
| drag **down**    | Show / Hide Desktop   |

Scroll wheel:

- **Vertical scroll is inverted for mice** (matches the "natural scroll" feel
  most Logi users prefer on an external mouse, independent of trackpad setting).
- **Trackpad scrolling is left alone** — discrimination is done via the
  `scrollWheelEventIsContinuous` property (0 = wheel, 1 = trackpad).
- Horizontal tilt passes through unchanged.

All other buttons (left / right / middle / back / forward) pass through
unchanged.

## Requirements

- macOS with **Universal Control** enabled (Ventura or newer recommended).
- **Logitech MX Master** connected to the *sending* Mac.
  Tested on **MX Master 3S**. Other MX Master generations should work since
  the button numbers (0–5) and scroll axes are the same, but are unverified.
- **Hammerspoon** on the *receiving* Mac — the Mac where the mouse is being
  used via UC but can't otherwise be configured with Logi Options+.

## Installation

### 1. Install Hammerspoon on the receiving Mac

Option A — Homebrew:

```bash
brew install --cask hammerspoon
```

Option B — direct download: <https://www.hammerspoon.org>

### 2. Drop in the config

```bash
mkdir -p ~/.hammerspoon
curl -fsSL https://raw.githubusercontent.com/DS-GM/univ-remote-for-logi/main/init.lua \
  -o ~/.hammerspoon/init.lua
```

Or clone and symlink:

```bash
git clone https://github.com/DS-GM/univ-remote-for-logi.git
ln -sf "$PWD/univ-remote-for-logi/init.lua" ~/.hammerspoon/init.lua
```

### 3. Launch Hammerspoon and grant permissions

```bash
open -a Hammerspoon
```

On first launch macOS will prompt for **Accessibility** permission. Approve it
in System Settings → Privacy & Security → Accessibility. Hammerspoon needs
this to create the event tap.

The first time you trigger a left/right drag gesture, macOS will also prompt
once for **Automation** permission — "Hammerspoon wants to control System
Events." Approve it. This is what lets the AppleScript path dispatch the
Ctrl+Arrow keystroke that switches spaces. No other permission is needed;
the rest of the actions go through Hammerspoon's own `hs.spaces` API.

### 4. Verify macOS space-switching shortcuts are enabled

System Settings → Keyboard → Keyboard Shortcuts… → Mission Control:

- ☑︎ Move left a space   (default ⌃←)
- ☑︎ Move right a space  (default ⌃→)

These must remain at their defaults. The script triggers them via AppleScript.

### 5. Reload config

Menu bar → 🔨 → **Reload Config**. You should see a transient alert:

> MX Master remap ON (gesture + scroll invert)

Drag the mouse from your sending Mac to the receiving one via Universal
Control, then try the gesture button. Open the Hammerspoon Console
(🔨 → Console) to watch `[gesture]` and `[scroll]` log lines.

## Customization

The top of `init.lua` has the tunables:

```lua
local DRAG_THRESHOLD = 40   -- px; below this a gesture counts as a click
local DEBUG = true          -- set false to silence the console
```

To change what each direction does, edit the five action functions at the top:
`missionControl`, `launchpad`, `showDesktop`, `desktopLeft`, `desktopRight`.
They are small wrappers around `hs.spaces.*` and an AppleScript keystroke.

To remap a different mouse button, change `btn ~= 5` in the handler. From the
receiving Mac, Universal Control forwards MX Master buttons as:

| Physical button   | CGEvent button number |
| ----------------- | --------------------- |
| left              | 0                     |
| right             | 1                     |
| middle (wheel)    | 2                     |
| thumb back        | 3                     |
| thumb forward     | 4                     |
| thumb gesture     | 5                     |

## Known Limitations

- **No UC / local discrimination.** CGEvents from Universal Control arrive
  with the same `srcPID=0` as local HID events, so the remap applies to any
  mouse on the receiving Mac. The trackpad exemption on scroll inversion
  works because trackpad events are flagged as continuous; there is no such
  flag for buttons.
- **Space switching uses an AppleScript subprocess.** `hs.eventtap.keyStroke`
  and `newKeyEvent:setFlags` both drop the `Ctrl` modifier when invoked from
  inside a `CGEventTap` callback
  ([Hammerspoon issue #2626](https://github.com/Hammerspoon/hammerspoon/issues/2626)).
  The AppleScript path works but adds ~50–100 ms. If the upstream bug is
  fixed, this can be swapped back to a native call.
- **Gesture cursor freeze is a side effect of swallowing.** While the thumb
  button is held, drag events are swallowed so the cursor stops moving — this
  mimics Logi Options+ gesture mode, but it is incidental, not a designed
  feature.

## License

MIT — see [LICENSE](LICENSE).
