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
#   systemd/system/ t2bce-audio.service, appletbdrm-rebind.service
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
    sudo systemctl enable t2bce-audio.service appletbdrm-rebind.service
fi

# scripts
for f in "$SYSTEM_SRC/scripts/"*; do
    sudo install -m 755 "$f" "/usr/local/bin/$(basename "$f")"
    echo "  -> /usr/local/bin/$(basename "$f")"
done

echo ""

echo ""
echo "Done."
echo ""
echo "If you changed a modprobe.d blacklist, rebuild the initramfs. On this"
echo "machine that is limine, not plain mkinitcpio: linux-cachyos ships no"
echo "/etc/mkinitcpio.d preset (only linux-cachyos-lts does), so 'mkinitcpio -P'"
echo "rebuilds the LTS image and leaves the running kernel's alone."
echo ""
echo "    sudo limine-mkinitcpio"
echo ""
echo "The audio blacklists here do not actually need it -- those modules are not"
echo "loaded from the initramfs, so /etc/modprobe.d on the real root governs them."
echo "hid_apple.conf DOES need it: hid/usbhid come up from the initramfs (apple_bce"
echo "at ~1.08s, just after 'Run /init'), so a stale copy is baked into the image and"
echo "wins at boot. Change it live too if you want it before the next reboot:"
echo ""
echo "    sudo sh -c 'echo 0 > /sys/module/hid_apple/parameters/swap_opt_cmd'"
