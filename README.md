# univ-remote-for-logi

Bring your Logitech MX Master gestures back when the mouse is being forwarded
to another Mac via **Universal Control**.

## Pick your mouse first

The gesture button changed number between generations, so there is one config
per generation. They are not interchangeable.

| Your mouse                     | Use this config                          | Gesture button |
| ------------------------------ | ---------------------------------------- | -------------- |
| **MX Master 4**                | [`mx-master-4/`](mx-master-4/)           | **6**          |
| **MX Master 3S / 3 / 2S**      | [`mx-master-3s/`](mx-master-3s/)         | **5**          |

```bash
git clone https://github.com/DS-GM/univ-remote-for-logi.git
cd univ-remote-for-logi

./switch.sh 4      # MX Master 4
./switch.sh 3s     # MX Master 3S / 3 / 2S
./switch.sh        # report which one is active
```

Switching is symmetric, so going back to the 3S later is just
`./switch.sh 3s`. Nothing is lost either way.

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

Thumb-rest gesture button:

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

Every other button passes through unchanged, including the MX Master 4's extra
side button.

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
That is why the two configs are kept separate rather than merged behind a
runtime check. The folder you install *is* the declaration of which mouse you
are on.

Verified on macOS with an MX Master 4 over Bluetooth LE (`0x046D` / `0xB042`),
which reports all seven buttons plus working horizontal tilt with no Logitech
software installed.

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

### 2. Install the config for your mouse

```bash
git clone https://github.com/DS-GM/univ-remote-for-logi.git
cd univ-remote-for-logi
./switch.sh 4        # or: ./switch.sh 3s
```

`switch.sh` copies the variant you chose to `~/.hammerspoon/init.lua`, backs up
any unrelated file that was already there, and reloads Hammerspoon.

It **copies rather than symlinks by default**, which is deliberate. macOS gates
`~/Documents`, `~/Desktop` and `~/Downloads` behind TCC. If your checkout sits
in one of those and Hammerspoon has not been granted Files and Folders access
to it, Hammerspoon cannot read through a symlink into the checkout, and
`init.lua` then fails to load **entirely**: no tap, no `hs.ipc`, no error, no
alert. Copying puts the file inside `~/.hammerspoon`, where that cannot happen.

If your checkout is somewhere Hammerspoon can read, `--link` gives you the
edit-in-place workflow instead:

```bash
./switch.sh 4 --link
```

Confirm the startup alert appears afterwards. Silence means it did not load.

If you would rather not use the script, copy one file by hand:

```bash
mkdir -p ~/.hammerspoon
curl -fsSL https://raw.githubusercontent.com/DS-GM/univ-remote-for-logi/main/mx-master-4/init.lua \
  -o ~/.hammerspoon/init.lua
```

Swap `mx-master-4` for `mx-master-3s` on an older mouse.

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

### 5. Confirm it loaded

You should see a transient alert naming the variant and button:

> MX Master 4 remap ON
> gesture button 6

Then try the gesture button. Open the Hammerspoon Console (🔨 › Console) to
watch the `[gesture]` log lines.

Both configs load `hs.ipc`, so you can also drive a running instance:

```bash
echo 'hs.reload()' | hs
```

Both configs auto-reload on any `.lua` save in `~/.hammerspoon`, so editing the
installed file takes effect immediately. When installed with `--link`, they also
watch the directory the symlink points into, so edits in the checkout reload too.

After a plain (copied) install, edits made in the checkout do not affect the
running config until you re-run `./switch.sh`.

## Customization

The top of each `init.lua` has the tunables:

```lua
local GESTURE_BUTTON = 6      -- set by the variant; see the table above
local DRAG_THRESHOLD = 40     -- px; below this a gesture counts as a click
local DEBUG          = true   -- set false to silence the console
local PROBE_MODE     = false  -- true = remap nothing, just report button numbers
```

To change what each direction does, edit the five action functions:
`missionControl`, `launchpad`, `showDesktop`, `desktopLeft`, `desktopRight`.
They are small wrappers around `hs.spaces.*` and an AppleScript keystroke.

### Finding the button number on a different mouse

Set `PROBE_MODE = true` and save. The config stops remapping and instead flashes
the CGEvent button number on screen each time you press one, and logs it to the
Hammerspoon Console. Press the button you want, note the number, set
`GESTURE_BUTTON` to it, then set `PROBE_MODE = false`.

This is also the fastest way to tell whether a button reaches macOS at all.

## Known Limitations

- **No UC / local discrimination for buttons.** CGEvents from Universal Control
  arrive with the same `srcPID=0` as local HID events, so the remap applies to
  any mouse on the receiving Mac. The trackpad exemption on scroll inversion
  works because trackpad events are flagged as continuous; there is no such
  flag for buttons. This is also why the mouse generation is chosen by which
  config you install rather than detected at runtime: over Universal Control
  there is no HID device on the receiving Mac to detect.
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
- **The MX Master 4's Actions Ring is not reproduced.** The MX Master 4 config
  treats the thumb-rest pad as a plain button. The radial menu, per-slot
  haptics, and app-aware slots that Logi Options+ draws on it all ride on
  Logitech's HID++ vendor protocol, which is not reachable from a `CGEventTap`.
- **A symlinked config inside a TCC-protected folder fails silently.** If
  `~/.hammerspoon/init.lua` is a symlink into `~/Documents`, `~/Desktop` or
  `~/Downloads` and Hammerspoon lacks Files and Folders access there, the
  config does not load at all. There is no error, no alert, and no console
  output, because the console output is itself produced by the file that never
  ran. The symptom is simply a mouse with no gestures and an `hs` CLI that
  reports the message port missing. This is why `switch.sh` copies by default.
- **The two configs are deliberately duplicated.** Each `init.lua` is
  self-contained so it can be curl'd as a single file. The cost is that a fix
  to shared logic has to be applied to both.

## License

MIT, see [LICENSE](LICENSE).
