#!/usr/bin/env bash
# apply-system.sh -- install everything under system/ that needs root.
#
# Run this after adding or changing anything in system/. install.sh calls it as
# its own system step, so the logic lives here once:
#
#     bash apply-system.sh
#
# What it covers:
#   modprobe.d/     T2 audio load order, hid_apple, Touch Bar autodim
#   tiny-dfr/       Touch Bar daemon config
#   ananicy.d/      Process priorities (voxtype, caelestia shell, browsers)
#   pacman.d/hooks/ Re-applies the themed voxtype OSD after a voxtype upgrade
#   polkit-1/       Power-management rules, if present
#   udev/rules.d/   T2 audio wake rule
#   systemd/system/ t2bce-audio.service
#   scripts/        -> /usr/local/bin (what the pacman hook calls)
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_SRC="$DOTFILES/system"

[ -d "$SYSTEM_SRC" ] || { echo "No system/ directory next to this script." >&2; exit 1; }

echo "==> Applying system configs from $SYSTEM_SRC (requires sudo)"


install_file() {
    local src="$1"
    local dst="$2"
    sudo mkdir -p "$(dirname "$dst")"
    sudo cp "$src" "$dst"
    echo "  -> $dst"
}

# Copy every file in system/<rel> to /etc/<rel>. Skips silently when the
# directory does not exist -- an unguarded glob expands to the literal path and
# aborts the whole script under `set -e`.
install_dir() {
    local rel="$1"
    local dst="${2:-/etc/$rel}"
    [ -d "$SYSTEM_SRC/$rel" ] || return 0
    local f
    for f in "$SYSTEM_SRC/$rel"/*; do
        [ -f "$f" ] || continue
        install_file "$f" "$dst/$(basename "$f")"
    done
}

install_dir modprobe.d
install_dir pacman.d/hooks
install_dir tiny-dfr
install_dir ananicy.d
install_dir polkit-1 /etc/polkit-1/rules.d

install_dir udev/rules.d
[ -d "$SYSTEM_SRC/udev/rules.d" ] && sudo udevadm control --reload-rules

install_dir systemd/system
if [ -d "$SYSTEM_SRC/systemd/system" ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable t2bce-audio.service
fi

# scripts
for f in "$SYSTEM_SRC/scripts/"*; do
    sudo install -m 755 "$f" "/usr/local/bin/$(basename "$f")"
    echo "  -> /usr/local/bin/$(basename "$f")"
done

echo ""

echo ""
echo "Done. Some changes (modprobe blacklists) need an initramfs rebuild:"
echo "    sudo mkinitcpio -P"
