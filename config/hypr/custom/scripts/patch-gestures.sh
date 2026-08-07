#!/bin/bash
# Re-applies 3-finger gesture config to hyprland/general.conf after updates.
# Run this after: cd ~/.cache/dots-hyprland && git stash && git pull && SKIP_MISCCONF=true ./setup install

CONF="$HOME/.config/hypr/hyprland/general.conf"

sed -i \
  -e 's/^gesture = 4, horizontal, workspace/gesture = 3, horizontal, workspace/' \
  -e 's/^gesture = 4, up,/gesture = 3, up,/' \
  -e 's/^gesture = 4, down,/gesture = 3, down,/' \
  -e 's/^gesture = 3, swipe, move,/gesture = 4, swipe, move,/' \
  "$CONF"

echo "Gestures patched. Run: hyprctl reload"
