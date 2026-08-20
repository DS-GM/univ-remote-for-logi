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

## Per-machine extras (optional)

Both configs try to load `~/.hammerspoon/extras.lua` once the mouse remap is
running:

```lua
local extrasOk, extrasErr = pcall(require, "extras")
```

A missing file is fine and silent. A file that fails to parse prints the error
to the Hammerspoon Console rather than dying quietly. `switch.sh` never touches
it, so personal or machine-specific bindings survive switching between the
`mx-master-4` and `mx-master-3s` variants.

[extras.lua.example](extras.lua.example) is a working file with three recipes
for the same two-Mac Universal Control desk this project targets. Copy it to
`~/.hammerspoon/extras.lua` and edit the `PEER` line. The first two need SSH from
the Mac holding the keyboard to the peer, so Remote Login on the peer and
key-only auth. The second also needs Hammerspoon running there.

### One key, displays off on both Macs

Binds a lock key to `pmset displaysleepnow` on both machines instead of locking
the screen. Displays only, so both Macs stay awake and Universal Control,
Tailscale and SSH keep running.

Probe your keyboard before binding, because what a lock key emits is often not
what the legend suggests. An MX Keys sends plain ⌃⌘Q, which is macOS's own
lock-screen shortcut. An 8BitDo Retro 108 sends Win+L, the Windows shortcut,
which is Left GUI + L on the wire, and that arrives as ⌥L rather than ⌘L on a
Mac which has Option and Command swapped for the keyboard under **System
Settings > Keyboard > Keyboard Shortcuts > Modifier Keys**.

### Caps Lock language switching across Universal Control

**Universal Control does not forward Caps Lock.** Measured with probes running
on both Macs at once: 13 presses produced 13 events on the sending Mac and zero
on the receiving one. For a CJK input method, where Caps Lock is the language
toggle, that leaves the peer stuck on ASCII.

Two approaches that look right and are not:

- Turning off the OS's own Caps-Lock-switches-language on the sender and
  reimplementing short versus long press in Hammerspoon. That setting is
  consumed in HIToolbox, which sits above WindowServer, so what the sender does
  with the key cannot change what WindowServer chooses to forward. Synthesising
  a substitute keystroke fails for the same reason: it passes through the same
  filter.
- Mirroring the input source with `hs.keycodes.inputSourceChanged`. While UC
  focus is on the peer, the sender's `currentSourceID` does not move at all. The
  tap sees the event, but HIToolbox has no local focused input context to act
  on, so there is no state change to mirror.

What works is to stop using the UC link for this and go around it. An eventtap
on the sender catches the Caps Lock press and asks the peer, over an already
multiplexed SSH connection, to switch its input source directly.

**Do not post a synthetic Caps Lock on the peer instead.** That was the first
version of this recipe, and it is worth explaining why it fails, because it works
often enough to look correct. Two back-to-back `newSystemKeyEvent(...):post()`
calls produce a press with no duration, and macOS chooses between "switch
language" and "lock uppercase" by how long the key is held, so a zero-length
press can land on either side. In practice the peer sometimes switched language
and sometimes engaged uppercase. Worse, there is no way back: since UC does not
forward Caps Lock, once uppercase is locked on the peer, no key you press can
release it. The relay could set that state but not clear it.

Setting the source directly loses nothing. The peer's own short-versus-long logic
is unreachable by definition, because a real Caps Lock never arrives there.
Measured deterministic: four of four clean alternations with the peer's `capslock`
flag staying false throughout.

The sender's own Caps Lock handling stays native, because the tap never swallows
the event. Only the peer is driven.

Latency needs care. A cold SSH measured 296 ms, enough for the first character
after a switch to land in the wrong language. With `ControlMaster` plus
`ControlPersist` the same round trip, remote `hs` call included, is 80 to 90 ms,
because most of a cold SSH is TCP and crypto negotiation rather than data. Two
gotchas that cost real time here: the control socket path has to stay short,
since a Unix domain socket path caps out near 104 characters and a longer one
simply fails, and the `hs` CLI blocks forever unless its stdin is redirected from
`/dev/null`.

### Never fork inside an eventtap callback

A `CGEventTap` callback is synchronous: WindowServer holds the event until the
callback returns. `hs.task.new():start()` forks a process, measured at 1.06 ms
median and 3.05 ms maximum, and that delay lands on the very key event that
triggered the callback. For Caps Lock it matters, because the delay hits key-down
while key-up goes through untouched, which skews the press duration macOS uses to
choose between switching language and locking uppercase. Repeated presses pile up
processes and make it worse.

Wrapping the spawn in `hs.timer.doAfter(0, ...)` costs 0.006 ms, 175 times less,
and moves the fork to the next event-loop pass. Every peer call in the example
goes through one helper that does exactly this.

### Making Caps Lock never lock uppercase

If Caps Lock is only ever wanted as a language key, the safest thing is to remove
the locked state rather than trying to make misfires rarer. Being stuck in
uppercase with no reliable way out is much worse than the misfire itself.

The example does it with two mechanisms on purpose:

- an eventtap on `flagsChanged` for keycode 57, which reacts a millisecond or two
  after the lock engages
- a 0.15 s timer polling `hs.hid.capslock.get()`, which is the actual guarantee

The timer is not redundant. Not every route into the locked state emits a
`flagsChanged`: `hs.hid.capslock.set()` writes the IOKit state directly and
produces no event at all, so a tap-only guard silently misses it. That is not
hypothetical, it is how the first version of this guard failed. `get()` costs
0.0865 ms, so polling at 0.15 s is roughly 0.06 percent of one core.

The tradeoff is that a long press still shows uppercase for up to 0.15 s before
it is dropped, so a stray capital can slip through if you type immediately.
Mapping Caps Lock to **No Action** under Modifier Keys prevents the lock
outright, but it kills the language switch along with it.

## Known Limitations

- **Universal Control does not forward Caps Lock.** Verified with simultaneous
  probes on both Macs: 13 presses, 13 events on the sender, zero on the
  receiver. Nothing on the receiving Mac can tap an event that never arrives, so
  a CJK language toggle bound to Caps Lock needs an out-of-band relay. See
  [Per-machine extras](#per-machine-extras-optional).
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
