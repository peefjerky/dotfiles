-- Animated gradient active-window border + a matching coloured glow, both
-- driven by the live Material scheme.
--
-- The original read end4's matugen output at
-- ~/.local/state/quickshell/user/generated/colors.json. Caelestia instead
-- regenerates ~/.config/hypr/scheme/current.lua and reloads Hyprland on every
-- scheme/wallpaper change, so requiring that module gives the same live-colour
-- behaviour with no file parsing — this is exactly how caelestia's own
-- variables.lua sources its colours.
--
-- Gradients must use the table form { colors = {...}, angle = N }; the
-- "rgba(...) rgba(...) 45deg" string form is rejected by hl.config.
-- Rotation comes from the `borderangle` loop animation in custom/animations.lua.

local scheme = require("scheme.current")

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

local BORDER_SIZE  = 3     -- drop to 2 for a thinner gradient
local GRADIENT_DEG = 45

-- Shadow / glow: OFF.
--
-- Caelestia ships a subtle shadow (inversePrimary at alpha 0x10, range 15,
-- render_power 4). It was retuned into a coloured glow here across several
-- passes and then turned off entirely — with a 3px animated gradient border
-- the window edge already reads clearly, and any shadow either overlapped the
-- neighbouring window (gaps_in is only 5, so there are just 10px between
-- tiles) or looked pasted on.
--
-- Set this back to true to restore it; the tunables below then apply.
local GLOW_ENABLED       = false
local GLOW_RANGE         = 6    -- keep under gaps_in*2 (=10) or it overlaps
local GLOW_RENDER_POWER  = 2
local GLOW_ALPHA         = "50"
local GLOW_ALPHA_INACTIVE = "10"

--------------------------------------------------------------------------------

local function rgba(hex, alpha)
    return string.format("rgba(%s%s)", hex, alpha or "ff")
end

-- Bail out rather than half-apply if the scheme is missing a key.
local keys = { "primaryContainer", "tertiaryContainer", "tertiary", "primary" }
local colors = {}
for i, key in ipairs(keys) do
    if type(scheme[key]) ~= "string" then return end
    colors[i] = rgba(scheme[key])
end

hl.config({
    general = {
        border_size = BORDER_SIZE,
        col = {
            active_border = {
                colors = colors,
                angle  = GRADIENT_DEG,
            },
        },
    },

    decoration = {
        shadow = {
            enabled        = GLOW_ENABLED,
            range          = GLOW_RANGE,
            render_power   = GLOW_RENDER_POWER,
            offset         = "0 0",
            sharp          = false,
            color          = rgba(scheme.primary, GLOW_ALPHA),
            color_inactive = rgba(scheme.inversePrimary or scheme.primary, GLOW_ALPHA_INACTIVE),
        },
    },
})
