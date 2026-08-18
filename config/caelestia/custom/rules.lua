-- Extra window rules, loaded after caelestia's hyprland/rules.lua so these are
-- purely additive -- nothing in the packaged file is edited.

-- hyprland.lua merges hypr-vars.lua into `variables` before any module loads, and
-- hypr-vars.lua reads shell.json, so this is caelestia's configured terminal --
-- not a hardcoded name. Change it in Settings > Apps and this follows.
local vars = require("variables")

-- Caelestia tags its own default terminal as opaque (hyprland/rules.lua:63-71,
-- by class). That default is foot, which isn't installed here, so the tag never
-- matched anything and the terminal was getting the 0.95 windowOpacity instead.
-- Tagging the configured one restores the intent.
if vars.terminal then
    hl.window_rule({ match = { class = vars.terminal }, tag = "+opaque" })
end
