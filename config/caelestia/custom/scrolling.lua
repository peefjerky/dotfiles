-- Scrolling layout: windows are placed on an infinitely growing horizontal tape
-- of columns. https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
--
-- Ported from the previous dots-hyprland setup (custom/general.lua). Caelestia
-- defaults to dwindle and — unlike end4's config — issues no dwindle-only
-- layoutmsg dispatches anywhere, so nothing here produces "no such layoutmsg
-- for scrolling" errors.

hl.config({
    general = {
        layout = "scrolling"
    },
    scrolling = {
        fullscreen_on_one_column = true,
        column_width             = 0.5,
        focus_fit_method         = 1, -- 0 = center, 1 = fit
        follow_focus             = true,
        follow_min_visible       = 0.4,
        explicit_column_widths   = "0.333, 0.5, 0.667, 1.0",
        wrap_focus               = true,
        wrap_swapcol             = true,
        direction                = "right" -- new windows/scroll go right; pairs with the horizontal swipe below
    }
})

--------------------------------------------------------------------------------
-- Gestures — one axis per concept
--------------------------------------------------------------------------------
--
-- Everything below is 3-finger, split by axis to match how the desktop is
-- actually laid out:
--   horizontal -> scrub the scrolling tape   (the tape is horizontal)
--   vertical   -> change workspace           (workspaces animate slidevert)
--
-- 4-finger gestures are removed entirely except caelestia's 4-finger-down
-- sleep gesture, which is left alone.
--
-- ORDER MATTERS: caelestia's hyprland/gestures.lua runs before this file, so
-- each unset below always finds its target and the whole file is idempotent
-- across reloads.
--
-- NEVER use direction = "swipe" in an unset. It is a WILDCARD matching any
-- direction for that finger count, so it removes one arbitrary gesture per
-- config load — it appears to work, then fails with "can't remove a
-- non-existent gesture" once it has silently eaten them all. Always unset the
-- specific direction you mean.

-- Horizontal: pan the tape.
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })

-- Vertical: workspace navigation. Caelestia binds 3-finger up/down to the
-- special workspace (`up` = special, `down` = fn.toggle("specialws")), so both
-- have to be released before they can be reused. The special workspace stays
-- reachable on SUPER+S, which is caelestia's own kbSpecialWs default.
hl.gesture({ fingers = 3, direction = "up", action = "unset" })
hl.gesture({ fingers = 3, direction = "down", action = "unset" })

-- Swipe up = next workspace: the content travels up and the incoming workspace
-- arrives from below, which is the direction slidevert actually animates.
hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = function()
        hl.dispatch(hl.dsp.focus({ workspace = "r+1" }))
    end
})
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function()
        hl.dispatch(hl.dsp.focus({ workspace = "r-1" }))
    end
})

-- Caelestia's 4-finger horizontal workspace swipe is removed. Beyond now being
-- redundant with the vertical gestures above, it used Hyprland's interactive
-- live-swipe renderer, which composites both adjacent workspaces for the whole
-- drag — under the scrolling layout an off-screen column from the neighbouring
-- workspace is not clipped during that render, producing a tail artifact. The
-- discrete dispatches above route through the normal animation path instead,
-- where no double-workspace composite happens.
--
-- Unsetting "horizontal" does NOT touch "left" or "right": each (fingers,
-- direction) pair is its own key, so the 4-finger left registration below is
-- free to use once the horizontal one is gone.
hl.gesture({ fingers = 4, direction = "horizontal", action = "unset" })

-- Caelestia's 4-finger-DOWN sleep gesture is kept. It runs vars.sleepGestureCmd,
-- which is overridden to plain `systemctl suspend` in hypr-vars.lua — the stock
-- value is `systemctl suspend-then-hibernate`, and hibernate is unavailable on
-- this machine's zram-only swap.

-- 4-finger swipe left reveals the sidebar — the same target as SUPER+N, which
-- caelestia binds as kbShowSidebar to the "caelestia:sidebar" global. Dispatching
-- the identical global keeps the two entry points in sync: if the sidebar is
-- rebound or reworked upstream, both follow.
--
-- Left is the direction that matches the motion: the sidebar lives on the right
-- edge, so swiping left drags it in.
hl.gesture({
    fingers   = 4,
    direction = "left",
    action    = function()
        hl.dispatch(hl.dsp.global("caelestia:sidebar"))
    end
})
