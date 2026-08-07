-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- hyprland/rules.lua has a catch-all no_blur for all windows; re-enable per-app
hl.window_rule({match = {class = "com.mitchellh.ghostty"}, no_blur = false})
hl.window_rule({match = {class = "kitty"}, no_blur = false})
hl.window_rule({match = {class = "zen"}, no_blur = false})
hl.window_rule({match = {class = "org.pwmt.zathura"}, no_blur = false})

-- Rain World: maximize to fill the workspace (not exclusive fullscreen)
hl.window_rule({match = {class = "steam_app_default", title = "Rain World"}, maximize = true})

-- xray blur on large sidebar layers forces a full 2560x1600 framebuffer capture every frame
-- on Intel iGPU (shared memory bandwidth). Disable xray for the notification center — it
-- still gets blurred, just against the immediate layer below rather than the desktop.
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, xray = false })
