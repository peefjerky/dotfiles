-- Loaded last (via hypr-user.lua), after caelestia's hyprland/keybinds.lua.
--
-- Every combo below was checked against `hyprctl binds -j` for collisions.
-- Multiple binds on one combo all fire together — Hyprland does not dedupe or
-- override — so a collision is a real bug, not a shadowing. The three combos
-- caelestia already owned (SUPER+ALT+Left/Right/Backslash) are freed by
-- reassigning them in hypr-vars.lua rather than by hl.unbind().

--------------------------------------------------------------------------------
-- Scrolling layout
--------------------------------------------------------------------------------

-- Focus column left/right (centers the focused column in view, wraps at ends)
hl.bind("SUPER + ALT + Left", hl.dsp.layout("focus l"), { description = "Scrolling: Focus column left" })
hl.bind("SUPER + ALT + Right", hl.dsp.layout("focus r"), { description = "Scrolling: Focus column right" })

-- Focus up/down *within* the current column. In horizontal scroll mode the
-- scrolling layout maps u/d to "previous/next target in strip" and l/r to
-- "previous/next strip", so these are the vertical counterpart of the two binds
-- above rather than a second way to change column.
--
-- These replace caelestia's SUPER+ALT+Up/Down height resize, which cannot work
-- under this layout — see the comment in hypr-vars.lua.
hl.bind("SUPER + ALT + Up", hl.dsp.layout("focus u"), { description = "Scrolling: Focus window above in column" })
hl.bind("SUPER + ALT + Down", hl.dsp.layout("focus d"), { description = "Scrolling: Focus window below in column" })

-- Move (swap) the current column with its neighbour, wraps at ends
hl.bind("SUPER + ALT + SHIFT + Left", hl.dsp.layout("swapcol l"), { description = "Scrolling: Move column left" })
hl.bind("SUPER + ALT + SHIFT + Right", hl.dsp.layout("swapcol r"), { description = "Scrolling: Move column right" })

-- Vertical counterpart: build and unbuild the stack the arrows above navigate.
-- There is no within-column reorder command in the layout (swapcol only takes
-- l/r), so up/down here mean "leave the stack" / "grow the stack" instead.
-- Same actions as SUPER+ALT+G / H below, on arrow keys.
hl.bind("SUPER + ALT + SHIFT + Up", hl.dsp.layout("expel"), { description = "Scrolling: Pop window out of the column" })
hl.bind("SUPER + ALT + SHIFT + Down", hl.dsp.layout("consume"), { description = "Scrolling: Stack next window into the column" })

-- Scroll the tape by one column without moving or refocusing anything.
-- SUPER+[ / ] are the primary keys; SUPER+ALT+Comma/Period kept as an alias.
hl.bind("SUPER + BracketLeft", hl.dsp.layout("move -col"),
    { repeating = true, description = "Scrolling: Scroll view left" })
hl.bind("SUPER + BracketRight", hl.dsp.layout("move +col"),
    { repeating = true, description = "Scrolling: Scroll view right" })
hl.bind("SUPER + ALT + Comma", hl.dsp.layout("move -col"),
    { repeating = true, description = "Scrolling: Scroll view left (alias)" })
hl.bind("SUPER + ALT + Period", hl.dsp.layout("move +col"),
    { repeating = true, description = "Scrolling: Scroll view right (alias)" })

-- Resize the focused column
hl.bind("SUPER + ALT + BracketLeft", hl.dsp.layout("colresize -0.1"),
    { repeating = true, description = "Scrolling: Shrink column" })
hl.bind("SUPER + ALT + BracketRight", hl.dsp.layout("colresize +0.1"),
    { repeating = true, description = "Scrolling: Widen column" })
-- Deliberately NOT SUPER+ALT+0: caelestia binds SUPER+ALT+<digit> to
-- "move window to workspace", so a "0" bind here would silently relocate the
-- focused window every time. Backslash is free once kbWindowPip is moved.
hl.bind("SUPER + ALT + Backslash", hl.dsp.layout("colresize 0.5"),
    { description = "Scrolling: Reset column width" })

-- Move windows between columns
hl.bind("SUPER + ALT + G", hl.dsp.layout("expel"), { description = "Scrolling: Pop window into its own column" })
hl.bind("SUPER + ALT + H", hl.dsp.layout("consume"), { description = "Scrolling: Merge window into previous column" })
hl.bind("SUPER + ALT + J", hl.dsp.layout("promote"), { description = "Scrolling: Promote window to a new column" })

-- View fitting. `fit` takes one of active/all/toend/tobeg/visible — an
-- unrecognised argument matches the `fit` branch, does nothing, and still
-- returns ok, so a typo here is a silent no-op rather than an error.
hl.bind("SUPER + ALT + Y", hl.dsp.layout("fit active"),
    { description = "Scrolling: Expand focused column to fill view" })
hl.bind("SUPER + ALT + SHIFT + Y", hl.dsp.layout("fit all"),
    { description = "Scrolling: Fit all columns on screen" })

--------------------------------------------------------------------------------
-- Window state
--------------------------------------------------------------------------------

-- Pseudo-fullscreen: tell the client it is fullscreen (so video players drop
-- their chrome and go edge-to-edge) while Hyprland keeps the window tiled at its
-- normal size. Good for watching something while working beside it.
--
-- Hyprland 0.56 removed the old `fakefullscreen` dispatcher -- `strings` on the
-- binary finds no such symbol -- so this is rebuilt on fullscreen_state, whose
-- two halves are exactly the split we want: `internal` is what the compositor
-- does, `client` is what the application is told.
--
-- Why the state is read back rather than using action = "toggle": since 0.55 a
-- `client` value of -1 ("leave unchanged") is treated as 0, so the natural
-- toggle form silently clears the state instead of flipping it. Reading
-- fullscreen_client and writing an absolute value is the workaround
-- acknowledged upstream in Hyprland discussion #14531.
--
-- Accepted limitation: fullscreen_state always writes both halves, so this also
-- forces internal = 0. Firing it on a maximized window drops the maximize. That
-- is Hyprland issue #7770 and is not fixable from config.
hl.bind("SUPER + ALT + F", function()
    local w = hl.get_active_window()
    if not w then return end
    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = 0,
        client = (w.fullscreen_client == 2) and 0 or 2,
        action = "set",
    }))
end, { description = "Window: Toggle pseudo-fullscreen (client-only)" })

--------------------------------------------------------------------------------
-- Shell extras
--------------------------------------------------------------------------------

-- Markdown notepad overlay (custom/notepad/, started by custom/notepad.lua).
-- hl.dsp.global fires the GlobalShortcut registered inside the running quickshell
-- process, so this costs no process spawn -- same mechanism caelestia uses for
-- its own panels.
hl.bind("SUPER + G", hl.dsp.global("notepad:toggle"), { description = "Toggle markdown notepad" })

--------------------------------------------------------------------------------
-- Hardware backlights (MacBookPro16,2)
--------------------------------------------------------------------------------

-- Keyboard backlight. `locked` so it still works on the lock screen.
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -sd ':white:kbd_backlight' set +25%"),
    { locked = true, repeating = true, description = "Hardware: Keyboard backlight up" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -sd ':white:kbd_backlight' set 25%-"),
    { locked = true, repeating = true, description = "Hardware: Keyboard backlight down" })

-- Touch Bar backlight, on the same keys with SUPER held.
-- appletb_backlight has max brightness 2 (off / dim / full), so this steps by
-- whole units rather than by a percentage — 25% of 2 rounds to the same ±1, but
-- the intent is clearer this way.
hl.bind("SUPER + XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -sd appletb_backlight set +1"),
    { locked = true, repeating = true, description = "Hardware: Touch Bar backlight up" })
hl.bind("SUPER + XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -sd appletb_backlight set 1-"),
    { locked = true, repeating = true, description = "Hardware: Touch Bar backlight down" })

--------------------------------------------------------------------------------
-- Dictation (voxtype)
--------------------------------------------------------------------------------

-- `voxtype setup compositor hyprland` was NOT run. It writes
-- ~/.config/hypr/conf.d/voxtype-submap.conf and hooks calling
-- `hyprctl dispatch submap <name>`; neither works here. Nothing sources conf.d
-- (this config is Lua), and hyprctl dispatch wraps its argument in
-- hl.dispatch(), so the classic dispatcher string is a syntax error -- verified:
--   hyprctl dispatch submap reset             -> error, ')' expected near 'reset'
--   hyprctl dispatch 'hl.dsp.submap("reset")' -> ok
-- Hence the submaps below, and ~/.local/bin/voxtype-submap for the config.toml
-- hooks.

-- Active while recording. F12 cancels and returns to normal. Both F12 binds
-- fire together -- Hyprland does not dedupe binds on one combo.
hl.define_submap("voxtype_recording", function()
    -- A submap REPLACES the active keymap, so every key that has to work while
    -- recording must be re-bound here. Without these two, F9-release and
    -- SUPER+CTRL+X are dead the moment recording starts and the only way out is
    -- F12 (cancel) -- i.e. recording that cannot be stopped, only discarded.
    hl.bind("F9", hl.dsp.exec_cmd("voxtype record stop"), { release = true })
    hl.bind("SUPER + CTRL + X", hl.dsp.exec_cmd("voxtype record toggle"))
    hl.bind("F12", hl.dsp.exec_cmd("voxtype record cancel"))
    hl.bind("F12", hl.dsp.submap("reset"))
end)

-- Active only while voxtype types the transcription out. Swallows the modifiers
-- so text arriving while SUPER is still held cannot fire window-management binds
-- ("hello" -> SUPER+h, SUPER+e, ...). Escape is deliberately NOT bound: it makes
-- wtype drop the first character (hyprwm/Hyprland#3165).
hl.define_submap("voxtype_suppress", function()
    for _, key in ipairs({
        "Super_L", "Super_R", "Control_L", "Control_R",
        "Alt_L", "Alt_R", "Shift_L", "Shift_R",
    }) do
        hl.bind(key, hl.dsp.exec_cmd("true"))
    end
    hl.bind("F12", hl.dsp.submap("reset")) -- escape hatch if voxtype dies mid-type
end)

-- Checked against `hyprctl binds -j`: SUPER+X (modmask 64) and SUPER+ALT+F12
-- (72) are taken, but SUPER+CTRL+X (68) and bare F9/F12 are free.
hl.bind("SUPER + CTRL + X", hl.dsp.exec_cmd("voxtype record toggle"),
    { description = "Dictation: Toggle recording" })

-- Push-to-talk. Two binds on F9: press starts, release stops.
hl.bind("F9", hl.dsp.exec_cmd("voxtype record start"),
    { description = "Dictation: Push-to-talk (hold)" })
hl.bind("F9", hl.dsp.exec_cmd("voxtype record stop"),
    { release = true, description = "Dictation: Push-to-talk release" })

--------------------------------------------------------------------------------
-- Fullscreen
--------------------------------------------------------------------------------

-- SUPER+SHIFT+F: fill the whole monitor WITHOUT telling the client.
--
-- Caelestia binds this combo to `fullscreen({ mode = "maximized" })` by default
-- (kbWindowBorderedFullscreen, parked in hypr-vars.lua). That mode is wrong
-- here: `scrolling.fullscreen_on_one_column = true` already gives a lone column
-- the full work area, and maximized then re-applies gaps_out on top, so the
-- window shrinks by 10px a side instead of growing.
--
-- Measured on one window (at / size):
--   tiled                        (78,23)  1499x954
--   internal = 1 (maximized)     (88,33)  1479x934   <- shrinks
--   internal = 2, client = 0     (0,0)    1600x1000  <- full monitor
--
-- client = 0 means the app is never told it is fullscreen, so browsers and
-- players keep their normal chrome instead of switching to their own
-- fullscreen UI. That is the difference from SUPER+F, which sets both.
-- Via a script because fullscreen_state SETS rather than toggles: pressing the
-- bind again just re-asserts fullscreen, with no way back out on the same key.
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/hypr-fullscreen-noclient"),
    { description = "Window: Toggle fullscreen without notifying the client" })
