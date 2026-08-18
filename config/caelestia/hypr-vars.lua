-- Caelestia variable overrides. Merged over ~/.config/hypr/variables.lua by
-- ~/.config/hypr/hyprland.lua BEFORE any of the hyprland/* modules are required,
-- so these take effect on caelestia's own keybind registrations.
--
-- Why this file exists instead of hl.unbind(): unbinding a default does not
-- reliably remove it in this Hyprland build (both the old and new bind stay in
-- `hyprctl binds -j` and fire together). Reassigning the variable means caelestia
-- never registers the bind in the first place, which actually works.

-- Default apps are caelestia's call, not this file's. shell.json is what the
-- Settings > Apps page writes, so it is the single source of truth and these
-- binds read straight out of it -- no second copy to drift.
--
-- Returns nil when the key is absent, which omits it from the override table
-- below and lets caelestia's own variables.lua default stand.
local function shell_app(key)
    local f = io.popen("jq -r '.general.apps." .. key .. " // empty | join(\" \")' "
        .. "'" .. os.getenv("HOME") .. "/.config/caelestia/shell.json' 2>/dev/null")
    if not f then return nil end
    local v = f:read("*l")
    f:close()
    if v == nil or v == "" then return nil end
    return v
end

return {
    -- Consumed by hyprland/keybinds.lua as hl.dsp.exec_cmd(vars.terminal) etc.
    -- Change these in the shell's settings UI, then `hyprctl reload`.
    terminal              = shell_app("terminal"),
    fileExplorer          = shell_app("explorer"),
    audioSettings         = shell_app("audio"),

    -- Caelestia has no browser setting, so this one stays owned here.
    -- "zen-browser" is the wrapper script in /usr/bin (the real binary lives at
    -- /opt/zen-browser-bin/zen-bin); use the wrapper so updates can't break it.
    browser               = "zen-browser",

    -- SUPER+Return opens the terminal. SUPER+T is caelestia's default and is
    -- kept as a second binding — drop it from this list if you want it freed.
    kbTerminal            = { "SUPER + Return", "SUPER + T" },

    -- The four arrow variants of these are wanted for scrolling-layout column
    -- navigation (see custom/keybinds.lua); each action keeps its primary,
    -- non-arrow binding.
    --
    -- The height pair is dropped from the arrows for a second reason: under the
    -- scrolling layout `resizeactive 0 ±N` is a no-op unless the column holds
    -- more than one window. ScrollingAlgorithm::resizeTarget only touches row
    -- heights inside `if (column->targetDatas.size() > 1)`, and with a delta of
    -- x=0 there is no width change either — so on a one-window column the
    -- keypress did literally nothing. It still works on floating windows, which
    -- take the `!DATA` branch and get resized directly, so the non-arrow
    -- bindings are worth keeping.
    kbWindowDecreaseWidth  = "SUPER + Minus",
    kbWindowIncreaseWidth  = "SUPER + Equal",
    kbWindowDecreaseHeight = "SUPER + SHIFT + Minus",
    kbWindowIncreaseHeight = "SUPER + SHIFT + Equal",

    -- SUPER+ALT+Backslash is wanted for "reset column width". PiP had no second
    -- binding, so it moves to SUPER+ALT+P (free; SUPER+P is pin-window).
    kbWindowPip           = "SUPER + ALT + P",

    -- SUPER+ALT+F is wanted for pseudo-fullscreen (see custom/keybinds.lua), so
    -- caelestia's bordered/maximized fullscreen moves to SUPER+SHIFT+F, which was
    -- free. Real fullscreen stays on SUPER+F (kbWindowFullscreen), untouched.
    kbWindowBorderedFullscreen = "SUPER + SHIFT + F",

    -- 4-finger-down sleep gesture. Caelestia's default is
    -- `systemctl suspend-then-hibernate`, which cannot work here: swap is
    -- zram-only, so logind reports CanHibernate = "na" and the call fails.
    -- Plain suspend goes through sleep.target, which is where the T2
    -- suspend/resume hooks live, so this is the path that actually works.
    sleepGestureCmd       = "systemctl suspend",

    -- Scroll speed. Caelestia ships 0.3, i.e. 30% of the delta libinput actually
    -- reports, which is what made scrolling feel sluggish. 1.0 passes libinput's
    -- pixel-precise delta through untouched, so a given finger travel moves the
    -- content about as far as it does on macOS.
    --
    -- Consumed by hyprland/input.lua as input:touchpad:scroll_factor. It must be
    -- set here rather than in custom/input.lua: this file is merged into
    -- variables.lua BEFORE that module runs, so setting it there would be
    -- overwritten by caelestia's own read of the variable.
    --
    -- Tune in 0.1 steps. Direction (natural_scroll) is already macOS-style and
    -- is caelestia's default.
    touchpadScrollFactor  = 1.0,
}
