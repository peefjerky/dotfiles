-- User overrides, loaded last by ~/.config/hypr/hyprland.lua.
-- Keybind/variable overrides that must land BEFORE caelestia's modules load
-- go in hypr-vars.lua instead.
--
-- Submodules resolve via the package.path entry hyprland.lua adds for
-- ~/.config/caelestia/?.lua, so "custom.scrolling" -> custom/scrolling.lua here.

-- Display scaling: 2560x1600 at 1.6 -> 1600x1000 logical.
-- Valid scale steps on this panel are 1.33 / 1.5 / 1.6.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1.6,
})

-- Push caelestia's default-app choices out to the XDG defaults (xdg-open and
-- friends). Runs on every config load, so `hyprctl reload` applies a change made
-- in Settings > Apps. Detached: config load must not block on it.
os.execute("(" .. os.getenv("HOME") .. "/.config/caelestia/custom/sync-default-apps.sh &) >/dev/null 2>&1")

-- hyprpm plugins are not loaded by Hyprland itself -- `hyprpm reload` has to run
-- once per session. The permission entry keeps that from raising a prompt (and is
-- only read at startup, never on `hyprctl reload`).
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")
end)

-- dynamic-cursors: shake-to-find magnifies 4x by default. With hyprcursor
-- resolution = -1 the magnified texture is loaded at [cursor size] * [base],
-- so 4x asks for 160px and overshoots what stays clean -- hence the pixelation.
-- 3x keeps it sharp. Everything else is left at plugin defaults (mode = "tilt").
-- nearest = 0 forces smooth scaling instead of nearest-neighbour, which is the
-- direct fix for the pixelation; base = 3.0 just reduces how far it has to scale.
hl.config({
    plugin = {
        dynamic_cursors = {
            shake = { base = 4.0, threshold = 4.0, speed = 6.0, limit = 3.0  },
            hyprcursor = { nearest = 0 },
        },
    },
})

require("custom.rules")
require("custom.input")
require("custom.scrolling")
require("custom.animations")
require("custom.border_colors")
require("custom.notepad")
require("custom.keybinds")
