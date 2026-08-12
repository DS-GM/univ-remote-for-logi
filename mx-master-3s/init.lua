-- =====================================================================
--  univ-remote-for-logi  ::  FOR THE LOGITECH MX MASTER 3S / 3 / 2S
-- =====================================================================
--  THIS FILE IS FOR THE MX MASTER 3S AND OLDER.
--  On an MX Master 4 the gesture button is a DIFFERENT number and this
--  config will do the wrong thing twice over: it will miss the gesture
--  pad, and it will swallow that mouse's new third side button.
--  Use ../mx-master-4/init.lua instead.
--
--  Why the two are not interchangeable:
--    The MX Master 4 added a third side button next to back and forward,
--    and that new button took CGEvent number 5. That pushed the thumb
--    rest, now the haptic "Actions Ring" pad, up to number 6.
--
--      button        MX Master 3S      MX Master 4
--      ------        ------------      -----------
--      back                 3                    3
--      forward              4                    4
--      third side    not present                 5   <- new
--      thumb rest           5                    6
--
--    On the 3S the thumb rest IS the gesture button and there is no
--    button 6. Hence GESTURE_BUTTON = 5 below.
-- =====================================================================
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
-- Note: CGEventTap cannot distinguish UC-forwarded events from local ones,
-- so this remap applies to ANY mouse on this Mac (including local Bluetooth).
-- Trackpad is exempt via the `isContinuous` scroll property.

local et    = hs.eventtap.event
local props = et.properties
local types = et.types

-- ---------- config ----------
local GESTURE_BUTTON = 5      -- MX Master 3S and older thumb gesture button.
                              -- On an MX Master 4 this is the new side button.
local DRAG_THRESHOLD = 40     -- px; below this counts as click
local DEBUG          = true   -- log gestures to the Hammerspoon console
local PROBE_MODE     = false  -- true = remap NOTHING, just report button numbers

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
            print(string.format("[probe] type=%s btn=%s", tostring(t), tostring(btn)))
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

-- ---------- conveniences ----------
-- `hs` CLI control of a running instance, e.g. echo 'hs.reload()' | hs
pcall(function() require("hs.ipc") end)

-- Auto-reload on any .lua change. When ~/.hammerspoon/init.lua is a symlink
-- into a checkout (the switch.sh workflow), the edits land in the checkout,
-- not here, so watch that directory too or they would never fire.
local function reloadOnLua(files)
    for _, f in ipairs(files) do
        if f:sub(-4) == ".lua" then hs.reload(); return end
    end
end
local home     = os.getenv("HOME")
local selfPath = home .. "/.hammerspoon/init.lua"
local watchDirs = { home .. "/.hammerspoon/" }
local resolved = hs.fs.pathToAbsolute(selfPath)
if resolved then
    local dir = resolved:match("^(.*/)[^/]*$")
    if dir and dir ~= watchDirs[1] then watchDirs[#watchDirs + 1] = dir end
end
cfgWatchers = {}
for _, d in ipairs(watchDirs) do
    cfgWatchers[#cfgWatchers + 1] = hs.pathwatcher.new(d, reloadOnLua):start()
end

-- ---------- startup banner ----------
if PROBE_MODE then
    hs.alert.show("MX Master 3S PROBE MODE\nremap disabled")
    print("==== UC-for-Logi [MX Master 3S] PROBE MODE (no remapping) ====")
else
    hs.alert.show("MX Master 3S remap ON\ngesture button " .. GESTURE_BUTTON)
    print("==== UC-for-Logi [MX Master 3S] remap started ====")
    print("gesture button " .. GESTURE_BUTTON .. " (thumb gesture button)")
    print("click=MC | L=DeskR R=DeskL U=Launchpad D=ShowDesktop")
    print("scroll: invert dy for mouse, trackpad unchanged")
end
