-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Scrolling layout keybinds
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/

-- Focus column left/right (centers the focused column in view, wraps at ends)
hl.bind("SUPER + ALT + Left", hl.dsp.layout("focus l"), { description = "Scrolling: Focus column left" })
hl.bind("SUPER + ALT + Right", hl.dsp.layout("focus r"), { description = "Scrolling: Focus column right" })

-- Move (swap) the current column with its neighbor, wraps at ends
hl.bind("SUPER + ALT + SHIFT + Left", hl.dsp.layout("swapcol l"), { description = "Scrolling: Move column left" })
hl.bind("SUPER + ALT + SHIFT + Right", hl.dsp.layout("swapcol r"), { description = "Scrolling: Move column right" })

-- Scroll the tape by one column without changing focus
hl.bind("SUPER + ALT + Comma", hl.dsp.layout("move -col"), { description = "Scrolling: Scroll tape left" })
hl.bind("SUPER + ALT + Period", hl.dsp.layout("move +col"), { description = "Scrolling: Scroll tape right" })

-- Resize the focused column. NOT bound to the default SUPER+;/' keys: those already
-- send "splitratio" (a dwindle-only layoutmsg, default hyprland/keybinds.lua:137-138),
-- which errors under the scrolling layout ("no such layoutmsg for scrolling") and
-- fires alongside any new bind added on the same keys (hl.unbind doesn't remove it).
hl.bind("SUPER + ALT + BracketLeft", hl.dsp.layout("colresize -0.1"),
    { repeating = true, description = "Scrolling: Shrink column" })
hl.bind("SUPER + ALT + BracketRight", hl.dsp.layout("colresize +0.1"),
    { repeating = true, description = "Scrolling: Widen column" })
-- Not bound to SUPER+ALT+0: the default hyprland/keybinds.lua binds the raw
-- keycode SUPER+ALT+code:19 (the physical "0" key) to "move window to workspace
-- group 10", which co-fires with any keysym "0" bind and silently relocates the
-- focused window every time you press this.
hl.bind("SUPER + ALT + Backslash", hl.dsp.layout("colresize 0.5"), { description = "Scrolling: Reset column width" })

-- Move windows between columns
hl.bind("SUPER + ALT + G", hl.dsp.layout("expel"), { description = "Scrolling: Pop window into its own column" })
hl.bind("SUPER + ALT + H", hl.dsp.layout("consume"), { description = "Scrolling: Merge window into previous column" })
hl.bind("SUPER + ALT + J", hl.dsp.layout("promote"), { description = "Scrolling: Promote window to a new column" })

-- View fitting. "fit_into_view" and "fit expand" don't exist in Hyprland 0.55.4
-- (fit_into_view landed later upstream; "expand" isn't a valid fit arg here -
-- only active/all/toend/tobeg/visible are, per ScrollingAlgorithm.cpp).
hl.bind("SUPER + ALT + Y", hl.dsp.layout("fit active"), { description = "Scrolling: Expand focused column to fill view" })
hl.bind("SUPER + ALT + SHIFT + Y", hl.dsp.layout("fit all"), { description = "Scrolling: Fit all columns on screen" })

-- Keyboard & Touch Bar backlight brightness (ported from keybinds.conf.bak)
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -sd :white:kbd_backlight set +25%"),
    { locked = true, repeating = true, description = "Hardware: Keyboard backlight up" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -sd :white:kbd_backlight set 25%-"),
    { locked = true, repeating = true, description = "Hardware: Keyboard backlight down" })

-- Workaround for a quickshell bug that spawns extra instances; kills all but
-- the longest-running one. See custom/scripts/kill-extra-quickshell.sh.
hl.bind("SUPER + ALT + K", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/kill-extra-quickshell.sh"),
    { description = "Quickshell: Kill extra instances" })

-- Reload Touch Bar (full recovery: handles start-limit-hit, stale DRM, etc.)
-- Requires /etc/sudoers.d/tiny-dfr-restart (NOPASSWD on /usr/local/bin/reload-touchbar.sh)
hl.bind("SUPER + CTRL + B", hl.dsp.exec_cmd("sudo /usr/local/bin/reload-touchbar.sh"),
    { description = "Hardware: Restart Touch Bar daemon" })
