# univ-remote-for-logi

Bring your Logitech MX Master gestures back when the mouse is being forwarded
to another Mac via **Universal Control**.

Supports **MX Master 4** and **MX Master 3S / 3 / 2S**. The gesture button moved
between those generations, so the script resolves it per model rather than
hardcoding one number. See [Button numbers](#button-numbers).

## The Problem

When you use Universal Control to share a Logitech mouse between two Macs, the
receiving Mac does not see the physical USB/Bluetooth device. It only sees
synthesized `CGEvent`s that Apple's WindowServer generates from the forwarded
motion and clicks. Because of that:

- **Logi Options+ on the receiving Mac cannot bind to the mouse** (there is no
  HID device with a matching VID/PID to attach to).
- SteerMouse, USB Overdrive, Karabiner-Elements, and any other IOKit-level
  tool all fail for the same reason.
- The thumb gesture button, horizontal tilt, and other "extra" inputs become
  dead weight on the receiving Mac.

The only layer where these events are visible is `CGEventTap`. This project
sits at that layer via Hammerspoon and re-implements the most-missed gestures.

## What It Does

Thumb-rest gesture button (button 6 on MX Master 4, button 5 on MX Master 3S
and older):

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
- **Trackpad scrolling is left alone.** Discrimination is done via the
  `scrollWheelEventIsContinuous` property (0 = wheel, 1 = trackpad).
- Horizontal tilt passes through unchanged.

All other buttons (left, right, middle, back, forward, and the MX Master 4's
extra side button) pass through unchanged.

## Button numbers

This is the part that bites when you upgrade the mouse.

| Physical button                  | MX Master 3S | MX Master 4 |
| -------------------------------- | ------------ | ----------- |
| left                             | 0            | 0           |
| right                            | 1            | 1           |
| middle (wheel click)             | 2            | 2           |
| thumb back                       | 3            | 3           |
| thumb forward                    | 4            | 4           |
| third side button *(new on MX4)* | not present  | **5**       |
| thumb rest                       | **5**        | **6**       |

The MX Master 4 added a third side button next to back and forward, and it took
number 5. That pushed the thumb rest, which is now the haptic **Actions Ring**
pad, up to number 6.

So a config hardcoded to button 5 does two wrong things at once on an MX Master
4: it never sees the gesture pad, and it silently swallows the new side button.
That is the bug this version fixes.

Verified on macOS with an MX Master 4 over Bluetooth LE (`0x046D` / `0xB042`),
which reports all seven buttons plus working horizontal tilt with no Logitech
software installed.

### How the number is resolved

1. The script runs `ioreg` at load and looks for a known model name among the
   HID devices this Mac can currently see.
2. On a match it uses that model's gesture button from `MODEL_GESTURE_BUTTON`.
3. On no match it uses `FALLBACK_GESTURE_BUTTON`.

Step 3 is the normal path for this project's original use case. Over Universal
Control there is no HID device to find, so detection cannot work and the
fallback constant is what actually applies. Set it to the generation you drive
that Mac with:

```lua
local FALLBACK_GESTURE_BUTTON = 6   -- 6 for MX Master 4, 5 for 3S and older
```

Detection re-runs on system wake and unlock, so swapping between two paired
mice is picked up without a manual reload.

## Requirements

- macOS with **Universal Control** enabled (Ventura or newer recommended).
- **Logitech MX Master** connected to the *sending* Mac.
  Tested on **MX Master 4** and **MX Master 3S**.
- **Hammerspoon** on the *receiving* Mac, the Mac where the mouse is being
  used via UC but cannot otherwise be configured with Logi Options+.

## Installation

### 1. Install Hammerspoon on the receiving Mac

Option A, Homebrew:

```bash
brew install --cask hammerspoon
```

Option B, direct download: <https://www.hammerspoon.org>

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
in System Settings › Privacy & Security › Accessibility. Hammerspoon needs
this to create the event tap.

The first time you trigger a left or right drag gesture, macOS will also prompt
once for **Automation** permission, "Hammerspoon wants to control System
Events." Approve it. This is what lets the AppleScript path dispatch the
Ctrl+Arrow keystroke that switches spaces. No other permission is needed;
the rest of the actions go through Hammerspoon's own `hs.spaces` API.

### 4. Verify macOS space-switching shortcuts are enabled

System Settings › Keyboard › Keyboard Shortcuts… › Mission Control:

- ☑︎ Move left a space   (default ⌃←)
- ☑︎ Move right a space  (default ⌃→)

These must remain at their defaults. The script triggers them via AppleScript.

### 5. Reload config

Edits to any `.lua` file in `~/.hammerspoon` reload automatically. You can also
use the menu bar (🔨 › **Reload Config**) or the CLI, since `hs.ipc` is loaded:

```bash
echo 'hs.reload()' | hs
```

You should see a transient alert naming the detected mouse and button:

> MX Master remap ON
> MX Master 4, button 6

Then try the gesture button. Open the Hammerspoon Console (🔨 › Console) to
watch the `[gesture]` log lines.

## Customization

The top of `init.lua` has the tunables:

```lua
local DRAG_THRESHOLD = 40     -- px; below this a gesture counts as a click
local DEBUG          = true   -- set false to silence the console
local PROBE_MODE     = false  -- true = remap nothing, just report button numbers
```

To change what each direction does, edit the five action functions:
`missionControl`, `launchpad`, `showDesktop`, `desktopLeft`, `desktopRight`.
They are small wrappers around `hs.spaces.*` and an AppleScript keystroke.

### Finding the button number on an unlisted mouse

Set `PROBE_MODE = true` and save. The script stops remapping and instead flashes
the CGEvent button number on screen each time you press one, and logs it to the
Hammerspoon Console. Press the button you want, note the number, then add a row:

```lua
local MODEL_GESTURE_BUTTON = {
    { "MX Master 4",  6 },
    { "MX Master 3S", 5 },
    -- { "Your Mouse",  N },
}
```

Order matters: the match is a plain substring, so more specific names go first.
`"MX Master 3"` would otherwise also match `"MX Master 3S"`.

Set `PROBE_MODE = false` when done.

## Known Limitations

- **No UC / local discrimination for buttons.** CGEvents from Universal Control
  arrive with the same `srcPID=0` as local HID events, so the remap applies to
  any mouse on the receiving Mac. The trackpad exemption on scroll inversion
  works because trackpad events are flagged as continuous; there is no such
  flag for buttons.
- **Model detection only works for a locally connected mouse.** That is a
  property of the problem, not a bug: over Universal Control there is no HID
  device on the receiving Mac to detect. `FALLBACK_GESTURE_BUTTON` is the knob
  that covers this case.
- **Space switching uses an AppleScript subprocess.** `hs.eventtap.keyStroke`
  and `newKeyEvent:setFlags` both drop the `Ctrl` modifier when invoked from
  inside a `CGEventTap` callback
  ([Hammerspoon issue #2626](https://github.com/Hammerspoon/hammerspoon/issues/2626)).
  The AppleScript path works but adds roughly 50 to 100 ms. If the upstream bug
  is fixed, this can be swapped back to a native call.
- **Gesture cursor freeze is a side effect of swallowing.** While the thumb
  button is held, drag events are swallowed so the cursor stops moving. This
  mimics Logi Options+ gesture mode, but it is incidental, not a designed
  feature.
- **The MX Master 4's Actions Ring is not reproduced.** This script treats the
  thumb-rest pad as a plain button. The radial menu, per-slot haptics, and
  app-aware slots that Logi Options+ draws on it all ride on Logitech's HID++
  vendor protocol, which is not reachable from a `CGEventTap`.

## License

MIT, see [LICENSE](LICENSE).
