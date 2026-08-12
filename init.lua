-- UC-for-Logi: MX Master remap on the RECEIVING Mac (via Universal Control)
--
-- Gesture button (the thumb rest):
--   click            → Mission Control
--   drag left        → Desktop Right
--   drag right       → Desktop Left
--   drag up          → Launchpad
--   drag down        → Show/Hide Desktop
-- Scroll wheel:
--   vertical         → INVERTED for mouse (MX Master), passthrough for trackpad
--   horizontal tilt  → passthrough
-- Every other button passes through untouched.
--
-- WHICH BUTTON IS THE GESTURE BUTTON DEPENDS ON THE GENERATION:
--
--   MX Master 3S and older : CGEvent button 5. The thumb rest IS the gesture
--                            button, and there is no button 6.
--   MX Master 4            : CGEvent button 6. The thumb rest became the
--                            haptic "Actions Ring" pad, and button 5 is now a
--                            NEW third side button sitting next to back and
--                            forward. Binding 5 on an MX Master 4 therefore
--                            does two wrong things at once: it misses the
--                            gesture pad, and it swallows a usable button.
--
-- So the number is resolved from whichever mouse this Mac can actually see,
-- and falls back to a constant when it can see none. That fallback is the
-- normal path for this project's original use case: over Universal Control the
-- receiving Mac gets synthesized CGEvents with no HID device behind them, so
-- there is nothing to detect.
--
-- Note: CGEventTap cannot distinguish UC-forwarded events from local ones,
-- so this remap applies to ANY mouse on this Mac (including local Bluetooth).
-- Trackpad is exempt via the `isContinuous` scroll property.

local et    = hs.eventtap.event
local props = et.properties
local types = et.types

-- ---------- config ----------
local DRAG_THRESHOLD = 40     -- px; below this counts as click
local DEBUG          = true   -- log gestures to the Hammerspoon console
local PROBE_MODE     = false  -- true = remap NOTHING, just report button numbers

-- Gesture button per model, most specific name first (the match is a plain
-- substring, and "MX Master 3" would otherwise also match "MX Master 3S").
-- Own something not listed? Set PROBE_MODE = true, press the button, read the
-- number off the screen, then add a row here.
local MODEL_GESTURE_BUTTON = {
    { "MX Master 4",  6 },
    { "MX Master 3S", 5 },
    { "MX Master 3",  5 },
    { "MX Master 2S", 5 },
}

-- Used when no known MX Master is visible to this Mac, which is exactly the
-- Universal Control case. Set this to the generation you drive this Mac with.
local FALLBACK_GESTURE_BUTTON = 6

-- ---------- model detection ----------
local GESTURE_BUTTON, GESTURE_SOURCE

local function resolveGestureButton()
    local out = hs.execute(
        "/usr/sbin/ioreg -c IOHIDDevice -r -d 1 2>/dev/null | grep '\"Product\"'"
    ) or ""
    for _, row in ipairs(MODEL_GESTURE_BUTTON) do
        local model, btn = row[1], row[2]
        if out:find(model, 1, true) then
            GESTURE_BUTTON, GESTURE_SOURCE = btn, model
            return
        end
    end
    GESTURE_BUTTON = FALLBACK_GESTURE_BUTTON
    GESTURE_SOURCE = "no local MX Master, assuming Universal Control"
end

resolveGestureButton()

-- ---------- actions ----------
local function missionControl() hs.spaces.toggleMissionControl() end
local function launchpad()      hs.spaces.toggleLaunchPad()      end
local function showDesktop()    hs.spaces.toggleShowDesktop()    end
-- Both hs.eventtap.keyStroke and newKeyEvent+setFlags fail to apply the Ctrl
-- modifier when invoked from inside a CGEventTap callback (issue #2626).
-- Workaround: shell out to osascript so the keystroke is synthesized from a
-- separate process, completely outside our event-tap context.
--   key code 123 = left arrow, 124 = right arrow
local function sendCtrlArrow(direction)
    local kc = direction == "left" and 123 or 124
    hs.task.new("/usr/bin/osascript", nil, {
        "-e",
        string.format(
            'tell application "System Events" to key code %d using control down',
            kc
        ),
    }):start()
end
local function desktopLeft()  sendCtrlArrow("left")  end
local function desktopRight() sendCtrlArrow("right") end

-- ---------- gesture classifier ----------
local function classify(dx, dy)
    local adx, ady = math.abs(dx), math.abs(dy)
    if adx < DRAG_THRESHOLD and ady < DRAG_THRESHOLD then return "click" end
    if adx >= ady then
        return dx < 0 and "left" or "right"
    else
        return dy < 0 and "up" or "down"
    end
end

-- ---------- state ----------
-- Accumulate event-level deltas instead of reading cursor position,
-- because we swallow the drag events (cursor is frozen while the button held).
local gesture = { active = false, dx = 0, dy = 0 }

-- ---------- event tap ----------
local tapTypes = {
    types.otherMouseDown,
    types.otherMouseDragged,
    types.otherMouseUp,
    types.scrollWheel,
}
-- Left and right are only interesting while probing, so they cost nothing
-- on the normal path.
if PROBE_MODE then
    table.insert(tapTypes, types.leftMouseDown)
    table.insert(tapTypes, types.rightMouseDown)
end

mxTap = hs.eventtap.new(tapTypes, function(e)
    local t = e:getType()

    -- ===== scroll: invert vertical for mouse only =====
    if t == types.scrollWheel then
        local isContinuous = e:getProperty(props.scrollWheelEventIsContinuous)
        if isContinuous == 0 then  -- 0 = discrete = physical wheel = mouse
            local d1  = e:getProperty(props.scrollWheelEventDeltaAxis1)      or 0
            local pd1 = e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0
            e:setProperty(props.scrollWheelEventDeltaAxis1,      -d1)
            e:setProperty(props.scrollWheelEventPointDeltaAxis1, -pd1)
        end
        return false  -- pass through (modified or not)
    end

    local btn = e:getProperty(props.mouseEventButtonNumber)

    -- ===== probe: report, never remap =====
    if PROBE_MODE then
        if t ~= types.otherMouseDragged then
            print(string.format("[probe] %s btn=%s", tostring(t), tostring(btn)))
            if t ~= types.otherMouseUp then
                hs.alert.closeAll()
                hs.alert.show("BUTTON  " .. tostring(btn), 1.2)
            end
        end
        return false
    end

    -- ===== gesture button =====
    if btn ~= GESTURE_BUTTON then return false end

    if t == types.otherMouseDown then
        gesture.active, gesture.dx, gesture.dy = true, 0, 0
        return true

    elseif t == types.otherMouseDragged then
        if gesture.active then
            gesture.dx = gesture.dx + (e:getProperty(props.mouseEventDeltaX) or 0)
            gesture.dy = gesture.dy + (e:getProperty(props.mouseEventDeltaY) or 0)
        end
        return true

    elseif t == types.otherMouseUp then
        if not gesture.active then return true end
        local dx, dy = gesture.dx, gesture.dy
        gesture.active = false
        local kind = classify(dx, dy)
        if DEBUG then
            print(string.format("[gesture] %-6s dx=%.0f dy=%.0f", kind, dx, dy))
        end
        if     kind == "click" then missionControl()
        elseif kind == "left"  then desktopRight()   -- drag LEFT  → Desktop Right
        elseif kind == "right" then desktopLeft()    -- drag RIGHT → Desktop Left
        elseif kind == "up"    then launchpad()
        elseif kind == "down"  then showDesktop()
        end
        return true
    end
    return false
end)

mxTap:start()

-- ---------- re-detect when the hardware may have changed ----------
-- Swapping mice mid-session, or waking with a different one paired, would
-- otherwise leave the wrong button bound until the next manual reload.
mxWake = hs.caffeinate.watcher.new(function(ev)
    local w = hs.caffeinate.watcher
    if ev == w.systemDidWake or ev == w.screensDidUnlock then
        local before = GESTURE_BUTTON
        resolveGestureButton()
        if DEBUG and GESTURE_BUTTON ~= before then
            print(string.format("[mx] re-detected %s, gesture button now %d",
                GESTURE_SOURCE, GESTURE_BUTTON))
        end
    end
end):start()

-- ---------- conveniences ----------
-- `hs` CLI control of a running instance (e.g. echo 'hs.reload()' | hs).
pcall(function() require("hs.ipc") end)

-- Auto-reload on any .lua change in ~/.hammerspoon so edits take effect
-- without touching the menu bar. Keep logs OUT of this directory or the
-- logger will retrigger the watcher in a loop.
local function reloadOnLua(files)
    for _, f in ipairs(files) do
        if f:sub(-4) == ".lua" then hs.reload(); return end
    end
end
cfgWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadOnLua):start()

-- ---------- startup banner ----------
if PROBE_MODE then
    hs.alert.show("MX Master PROBE MODE\nremap disabled")
    print("==== UC-for-Logi PROBE MODE (no remapping) ====")
else
    hs.alert.show(string.format(
        "MX Master remap ON\n%s, button %d", GESTURE_SOURCE, GESTURE_BUTTON))
    print("==== UC-for-Logi remap started ====")
    print(string.format("detected: %s → gesture button %d",
        GESTURE_SOURCE, GESTURE_BUTTON))
    print("click=MC | L=DeskR R=DeskL U=Launchpad D=ShowDesktop")
    print("scroll: invert dy for mouse, trackpad unchanged")
end
