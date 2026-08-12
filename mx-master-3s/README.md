# MX Master 3S / 3 / 2S config

**For the Logitech MX Master 3S and older.** Gesture button is CGEvent **5**,
the thumb gesture button under the thumb rest.

This is the original behavior of this project, kept as a first-class option.

Do not use this on an MX Master 4. There, button 5 is a new third side button
next to back and forward, so this config would miss the gesture pad and swallow
a usable button. Use [`../mx-master-4/`](../mx-master-4/) instead.

Install from the repo root:

```bash
./switch.sh 3s
```

Full documentation, including the button-number table and why the two
generations differ, is in the [top-level README](../README.md).
