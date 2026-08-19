-- Touchpad: make physical press-to-click work.
--
-- The internal trackpad is USB 05AC:027E over the T2 (bce-vhci), driven by
-- hid-magicmouse. It correctly advertises INPUT_PROP_BUTTONPAD and BTN_LEFT
-- (0x110) and nothing else -- no BTN_RIGHT, no BTN_MIDDLE. That is normal for a
-- clickpad: every button other than left is synthesised by libinput, so which
-- one you get depends entirely on libinput's click method.
--
-- libinput matches this device on [Apple Touchpads USB] (MatchVendor=0x05AC,
-- MatchBus=usb, MatchUdevType=touchpad) and sets ModelAppleTouchpad=1, whose
-- default click method is CLICKFINGER. Hyprland does not inherit that: its own
-- clickfinger_behavior option defaults to false and is pushed into libinput at
-- device init, overwriting the Apple default with BUTTON_AREAS every start.
-- caelestia never sets it either (hyprland/input.lua only touches
-- natural_scroll, disable_while_typing, scroll_factor), so button-areas won.
--
-- Under button-areas the only right-click is the bottom-right corner, sized from
-- libinput's AttrSizeHint of 104x75 mm while this pad is really 132x82 mm
-- (ID_INPUT_WIDTH_MM/HEIGHT_MM), so the target lands inside the surface rather
-- than at its corner. clickfinger drops geometry entirely -- finger count picks
-- the button, anywhere on the pad -- which is also what macOS does:
--
--   1 finger -> left, 2 fingers -> right, 3 fingers -> middle
--
-- NOTHING WITH A HYPHEN IN ITS NAME CAN BE SET FROM HERE. The Lua provider
-- silently rejects quoted hyphenated keys such as ["tap-to-click"] and
-- ["tap-and-drag"] -- they parse as Lua but never reach Hyprland (hyprctl
-- getoption reports set: false) and they raise a config error. Both already
-- default to true, so there is nothing to gain by naming them.
--
-- Keyboard layout: caelestia's hyprland/input.lua hardcodes kb_layout = "us".
-- This file is required from hypr-user.lua, which loads after it, so setting
-- it again here wins. in(eng) is "English (India, with rupee)": character for
-- character the US layout, plus AltGr+4 -> Rs.
--
-- This does NOT affect modifier positions. Which physical key emits SUPER is
-- decided by hid-apple's swap_opt_cmd (see system/modprobe.d/hid_apple.conf),
-- not by xkb -- no layout puts Command and Option in different places.

hl.config({
    input = {
        kb_layout  = "in",
        kb_variant = "eng",

        touchpad = {
            clickfinger_behavior = true,
        },
    },
})
