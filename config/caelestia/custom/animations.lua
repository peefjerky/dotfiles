-- Animation retune, ported from the previous setup.
--
-- Caelestia's emphasizedDecel is {0.05,0.7},{0.1,1} — an initial slope of 14,
-- meaning the first rendered frame already shows ~70% of the total travel. It
-- reads as a dropped frame rather than a motion. smoothDecel (easeOutCubic)
-- spreads the motion evenly. There is no GPU cost difference between bezier
-- shapes, just a smoother-looking curve.
hl.curve("smoothDecel", {
    type   = "bezier",
    points = { { 0.33, 1.0 }, { 0.68, 1.0 } }
})

-- Workspace switch: VERTICAL slide, deliberately.
--
-- Horizontal `slide` (caelestia's default, and Hyprland's) is broken under the
-- scrolling layout. During the transition Hyprland renders the outgoing
-- workspace at an x-offset, but it sizes that offset to the MONITOR width — it
-- has no notion of the tape being wider. So columns that were clipped off the
-- right edge get translated into the viewport as the workspace shifts left: a
-- window you would never otherwise see steps in from the side, and the switch
-- reads as cut off rather than as a motion.
--
-- `fade` avoids it by leaving renderOffset at (0,0), but gives up the motion.
-- `slidevert` keeps the motion and simply moves it to the axis the tape does
-- not occupy: the offset is applied in y, x positions are untouched, so no
-- off-screen column can enter the viewport. Same feel, no artifact.
--
-- Do NOT change this to `slide`, `slidefade`, or any horizontal variant while
-- the scrolling layout is in use — `slidefade` still applies the full slide
-- offset under the hood and reproduces the bug exactly.
--
-- Curve: caelestia's own vocabulary is Material 3 motion — its "standard" is
-- literally MD3 Emphasized, (0.2,0),(0,1). That curve eases IN, so it starts
-- from a standstill; over a full monitor height of travel that reads as lag
-- before the workspace commits to moving.
--
-- MD3's answer for large incoming transitions is Emphasized Decelerate,
-- (0.05,0.7),(0.1,1) — which caelestia already ships as `emphasizedDecel`. But
-- its initial slope is 14, so the very first frame is already 70% of the way
-- there and the motion reads as a jump cut rather than a slide.
--
-- wsSlideVert keeps the MD3 decelerate SHAPE — immediate response, long settle
-- — with the opening slope pulled back to ~5.7 so the first frames are visible
-- as travel. It stays inside caelestia's design language rather than importing
-- a foreign easing.
hl.curve("wsSlideVert", { type = "bezier", points = { { 0.15, 0.85 }, { 0.25, 1.0 } } })

-- Speed matches caelestia's own workspace registration; only the axis and the
-- curve differ from upstream.
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wsSlideVert", style = "slidevert" })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "smoothDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "smoothDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "smoothDecel", style = "slide" })

-- fadeIn/fadeOut are children of caelestia's `fade` leaf and layersIn/
-- fadeLayersIn of `fadeLayers`; setting a child after the parent overrides it.
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "smoothDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "smoothDecel" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "smoothDecel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.7, bezier = "smoothDecel", style = "popin 93%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.5, bezier = "smoothDecel" })

-- Drives the rotation of the gradient border in custom/border_colors.lua.
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })

-- layersOut / fadeLayersOut / specialWorkspace keep caelestia's accel curves —
-- those are deliberate quick-exit shapes, not the same "abrupt start" problem.

-- Blur perf, Intel Ice Lake iGPU: caelestia leaves vibrancy and noise at
-- Hyprland's defaults (0.1696 / 0.0117) and each costs an extra shader pass per
-- blurred layer. Neither is visible at blurSize 8. Delete this block if you
-- want the stock look back — size/passes are already 8/2 via caelestia's vars.
hl.config({
    decoration = {
        blur = {
            vibrancy = 0,
            noise    = 0,
        }
    }
})

-- Window alpha transitions (SUPER+SHIFT+T, and any rule-driven opacity change).
--
-- `fadeSwitch` is the leaf Hyprland uses when a window's alpha goal changes,
-- as opposed to `fadeIn`/`fadeOut`, which only cover a window appearing or
-- disappearing. Caelestia configures the whole fade family EXCEPT this one, so
-- toggling the "opaque" tag snapped between 0.95 and 1.0 with no transition.
-- Verified it is a real leaf: `hl.animation` errors with "no such animation
-- leaf" on a bogus name and returns ok for this one.
--
-- Hyprland's `speed` is a DURATION in ds (1 = 100ms), so higher is slower --
-- caelestia's fadeLayersIn at 0.5 is 50ms, its fade at 6 is 600ms. 8 = 800ms,
-- longer than any of them on purpose: the alpha delta here is only 0.05
-- (windowOpacity 0.95 -> 1.0), and across a change that small a short fade is
-- indistinguishable from a snap. The duration is doing the work the contrast
-- cannot.
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 8, bezier = "standard" })
