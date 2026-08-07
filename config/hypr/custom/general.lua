-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- MBP 2020: 2560x1600 @ 226 PPI — scale 1.6 gives ~1600x1000 logical
hl.monitor({
    output = "eDP-1",
    mode = "2560x1600@60",
    position = "auto",
    scale = 1.6
})

-- Scrolling layout: windows are placed on an infinitely growing horizontal tape
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.config({
    general = {
        layout = "scrolling"
    },
    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.5,
        focus_fit_method = 1, -- 0 = center, 1 = fit
        follow_focus = true,
        follow_min_visible = 0.4,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
        wrap_focus = true,
        wrap_swapcol = true,
        direction = "right" -- new windows/scroll go right; pairs with the horizontal swipe gesture below
    }
})

-- 3-finger swipe scrolls the tape. Same-signature re-registration gets shadowed by
-- the earlier-loaded default, so the default must be unset first before registering
-- the scroll_move action. As of the dots-hyprland update bringing in Hyprland's
-- 3-finger "move window" gesture, the default signature is {fingers=3, direction="swipe",
-- action="move"} (was {fingers=3, direction="horizontal", action="workspace"} before).
-- "swipe" is a wildcard that shadows any more specific direction (e.g. "horizontal"), so
-- it must be unset using "swipe" itself; once removed, "horizontal" no longer collides.
hl.gesture({ fingers = 3, direction = "swipe", action = "unset" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })

-- 4-finger workspace swipe (default: {fingers=4, direction="horizontal", action="workspace"})
-- uses Hyprland's interactive live-swipe renderer, which always composites both
-- adjacent workspaces while dragging and ignores the "workspaces" animation leaf
-- entirely. With the scrolling layout, a column peeking in from the next
-- workspace isn't clipped during that live render, causing the tail artifact
-- (same root cause as the quickshell overview clipping bug, just in Hyprland's
-- own compositor path this time, which we can't patch directly). Switching to
-- discrete left/right triggers (same mechanism as the up/down quickshell-toggle
-- gesture below) routes through the normal dispatch+animation path instead —
-- the same path keybinds use, where slidefade actually applies and there's no
-- live double-workspace composite.
hl.gesture({ fingers = 4, direction = "horizontal", action = "unset" })
hl.gesture({
    fingers = 4,
    direction = "left",
    action = function()
        hl.dispatch(hl.dsp.focus({ workspace = "r+1" }))
    end
})
hl.gesture({
    fingers = 4,
    direction = "right",
    action = function()
        hl.dispatch(hl.dsp.focus({ workspace = "r-1" }))
    end
})

-- Apple keyboard: the system-wide hid_apple driver has swap_opt_cmd=1, so the physical
-- Option key reports as Super and Command reports as Alt. This XKB option swaps them
-- again at the Hyprland layer, restoring Command = SUPER and Option = ALT.
hl.config({
    input = {
        kb_options = "altwin:swap_alt_win"
    }
})

-- Reduce blur passes 3→2 to cut per-frame GPU cost during slide animations.
-- The default emphasizedDecel curve has y1/x1=14 (14× initial velocity), meaning
-- the first rendered frame already shows ~70% of the total travel — looks like a
-- dropped frame. smoothDecel (easeOutCubic) spreads the motion more evenly.
hl.config({
    decoration = {
        blur = {
            passes = 2,
            size = 8,
            vibrancy = 0,    -- vibrancy runs an extra shader pass; not visible at this blur size
            noise = 0,       -- noise overlay costs a render pass per blurred layer
        }
    }
})

hl.curve("smoothDecel", {
    type = "bezier",
    points = {{0.33, 1.0}, {0.68, 1.0}}
})

-- Plain "fade" avoids two problems with scrolling layout + slide:
-- 1. the tape is wider than the monitor, so the off-screen column briefly enters
--    the viewport as workspace 1 slides out → artifact of last window appearing then
--    vanishing; 2. slide requires compositing both workspaces side-by-side the whole
--    time → expensive; fade only composites one workspace at any given alpha value.
-- NOTE: "slidefade" (used previously) still applies the full slide offset under the
-- hood (DesktopAnimationManager.cpp) on top of the fade — same compositing cost as
-- slide plus extra blending, which is why switches felt laggy. Plain "fade" skips the
-- offset entirely (renderOffset stays at (0,0)), so it's the actually-cheap style.
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 4,
    bezier = "smoothDecel",
    style = "fade"
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 3,
    bezier = "smoothDecel",
    style = "popin 80%"
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2,
    bezier = "smoothDecel",
    style = "popin 90%"
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 3,
    bezier = "smoothDecel",
    style = "slide"
})

-- Same abrupt-curve issue as the old workspace slidefade (first frame already
-- ~70-100% there) shows up on several other leaves too — the defaults use
-- emphasizedDecel (slope 14) or menu_decel (slope 10). Free fix: swap to
-- smoothDecel, same as windows/workspaces above. No GPU cost difference
-- between bezier shapes, just a smoother-looking curve.
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "smoothDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "smoothDecel" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "smoothDecel" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.7, bezier = "smoothDecel", style = "popin 93%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.5, bezier = "smoothDecel" })
-- layersOut/fadeLayersOut/specialWorkspaceOut intentionally keep their accel/stall
-- curves (menu_accel, stall) — those are deliberate quick-exit shapes, not the
-- same "abrupt start" bug, so left untouched.

-- Animated border colors from matugen (re-reads colors.json on every config reload)
require("custom.border_colors")
