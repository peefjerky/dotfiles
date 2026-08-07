-- Reads matugen's colors.json and applies a vibrant animated gradient border.
-- Re-evaluated on every config reload (dots-hyprland triggers this on wallpaper change).
-- Gradient requires table format { colors = {...}, angle = N } — string format is rejected
-- by hl.config in Hyprland 0.55.4 (confirmed via hyprctl eval).
local function get_color(json, key)
    return json:match('"' .. key .. '":%s*"#(%x+)"')
end

local f = io.open(HOME .. "/.local/state/quickshell/user/generated/colors.json", "r")
if f then
    local json = f:read("*a")
    f:close()
    local c1 = get_color(json, "primary_container")
    local c2 = get_color(json, "tertiary_container")
    local c3 = get_color(json, "tertiary")
    local c4 = get_color(json, "primary")
    if c1 and c2 and c3 and c4 then
        hl.config({
            general = {
                border_size = 3,
                col = {
                    active_border = {
                        colors = {
                            string.format("rgba(%sff)", c1),
                            string.format("rgba(%sff)", c2),
                            string.format("rgba(%sff)", c3),
                            string.format("rgba(%sff)", c4),
                        },
                        angle = 45,
                    },
                },
            },
        })
    end
end
