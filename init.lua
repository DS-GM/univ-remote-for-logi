-- UC-for-Logi: MX Master remap on the RECEIVING Mac (via Universal Control)
-- btn=5 (thumb gesture button):
--   click            → Mission Control
--   drag left        → Desktop Right
--   drag right       → Desktop Left
--   drag up          → Launchpad
--   drag down        → Show/Hide Desktop
-- Scroll wheel:
--   vertical         → INVERTED for mouse (MX Master), passthrough for trackpad
--   horizontal tilt  → passthrough
-- All other buttons (0,1,2,3,4) passthrough.
--
-- Note: CGEventTap cannot distinguish UC-forwarded events from local ones,
-- so this remap applies to ANY mouse on this Mac (including local Bluetooth).
-- Trackpad is exempt via the `isContinuous` scroll property.

local et    = hs.eventtap.event
local props = et.properties
local types = et.types

local DRAG_THRESHOLD = 40   -- px; below this counts as click
local DEBUG = true

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
-- because we swallow the drag events (cursor is frozen while btn=5 held).
local gesture = { active = false, dx = 0, dy = 0 }

-- ---------- event tap ----------
mxTap = hs.eventtap.new({
    types.otherMouseDown,
    types.otherMouseDragged,
    types.otherMouseUp,
    types.scrollWheel,
}, function(e)
    local t = e:getType()

    -- ===== scroll: invert vertical for mouse only =====
    if t == types.scrollWheel then
        local isContinuous = e:getProperty(props.scrollWheelEventIsContinuous)
        if isContinuous == 0 then  -- 0 = discrete = physical wheel = mouse
            local d1  = e:getProperty(props.scrollWheelEventDeltaAxis1)      or 0
            local pd1 = e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0
            e:setProperty(props.scrollWheelEventDeltaAxis1,      -d1)
            e:setProperty(props.scrollWheelEventPointDeltaAxis1, -pd1)
            if DEBUG then print(string.format("[scroll] mouse invert dy: %d → %d", d1, -d1)) end
        end
        return false  -- pass through (modified or not)
    end

    -- ===== gesture button (btn=5) =====
    local btn = e:getProperty(props.mouseEventButtonNumber)
    if btn ~= 5 then return false end

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
hs.alert.show("MX Master remap ON\n(gesture + scroll invert)")
print("==== UC-for-Logi remap started ====")
print("btn=5: click=MC | L=DeskR R=DeskL U=Launchpad D=ShowDesktop")
print("scroll: invert dy for mouse, trackpad unchanged")
