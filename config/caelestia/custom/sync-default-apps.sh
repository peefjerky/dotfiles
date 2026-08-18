#!/usr/bin/env bash
#
# Caelestia's shell.json is the single source of truth for default apps. This
# pushes what Settings > Apps says out to the XDG defaults, so xdg-open -- and
# therefore every other application on the system -- agrees with it.
#
# The other consumer, Hyprland's SUPER+T / SUPER+E, reads the same JSON directly
# rather than going through here (see ~/.config/caelestia/hypr-vars.lua). Nothing
# holds a second copy of these values.
#
# Runs on every Hyprland config load (hypr-user.lua), so `hyprctl reload` applies
# a change made in the settings UI. Safe to run by hand at any time.

set -euo pipefail

CONFIG=${CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json}
[[ -f $CONFIG ]] || exit 0

# The .desktop entry whose Exec launches this binary. Preferring an exact
# <binary>.desktop first matters because a grep alone is ambiguous: thunar ships
# thunar-settings.desktop and thunar-bulk-rename.desktop alongside thunar.desktop.
desktop_for() {
    local bin=$1 hit
    for dir in "$HOME/.local/share/applications" /usr/share/applications; do
        [[ -f $dir/$bin.desktop ]] && { echo "$bin.desktop"; return 0; }
    done
    hit=$(grep -rlE "^Exec=(/usr/bin/)?$bin([[:space:]]|$)" \
        "$HOME/.local/share/applications" /usr/share/applications 2>/dev/null | head -1)
    [[ -n $hit ]] && { echo "${hit##*/}"; return 0; }
    return 1
}

# Only the file manager has XDG mime types worth claiming. There is no standard
# handler for "terminal" or "audio mixer", so those two exist in shell.json for
# caelestia's and Hyprland's use only and are not pushed anywhere.
explorer=$(jq -r '.general.apps.explorer[0] // empty' "$CONFIG")
[[ -n $explorer ]] || exit 0

if ! entry=$(desktop_for "$explorer"); then
    echo "sync-default-apps: no .desktop found for '$explorer', leaving XDG defaults alone" >&2
    exit 1
fi

xdg-mime default "$entry" \
    inode/directory \
    x-directory/normal \
    application/x-gnome-saved-search

# Only speak up when something actually moved -- this runs on every reload.
[[ ${VERBOSE:-} ]] && echo "sync-default-apps: directories -> $entry"
exit 0
