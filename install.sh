#!/usr/bin/env bash
# install.sh -- deploy dotfiles to the running system
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES/config"
CONFIG_DST="$HOME/.config"

echo "==> Dotfiles: $DOTFILES"
echo "==> Config destination: $CONFIG_DST"
echo ""

# --------------------------------------------------------
# User configs (~/.config/)
# --------------------------------------------------------
echo "[1/3] Symlinking user configs..."

for entry in "$CONFIG_SRC"/*/; do
    name="$(basename "$entry")"
    dst="$CONFIG_DST/$name"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "  SKIP $name (exists and is not a symlink -- back it up first)"
        continue
    fi
    ln -sfn "$entry" "$dst"
    echo "  -> $name"
done

# Single-file configs
for f in starship.toml thorium-flags.conf electron-flags.conf chrome-flags.conf code-flags.conf; do
    src="$CONFIG_SRC/$f"
    dst="$CONFIG_DST/$f"
    [ -f "$src" ] || continue
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "  SKIP $f (exists and is not a symlink)"
        continue
    fi
    ln -sf "$src" "$dst"
    echo "  -> $f"
done

echo ""

# --------------------------------------------------------
# System configs (/etc/, /usr/local/bin/)
# --------------------------------------------------------
echo "[2/3] Applying system configs (requires sudo)..."

SYSTEM_SRC="$DOTFILES/system"

install_file() {
    local src="$1"
    local dst="$2"
    sudo mkdir -p "$(dirname "$dst")"
    sudo cp "$src" "$dst"
    echo "  -> $dst"
}

# modprobe.d
for f in "$SYSTEM_SRC/modprobe.d/"*; do
    install_file "$f" "/etc/modprobe.d/$(basename "$f")"
done

# udev rules
for f in "$SYSTEM_SRC/udev/rules.d/"*; do
    install_file "$f" "/etc/udev/rules.d/$(basename "$f")"
done
sudo udevadm control --reload-rules

# systemd units
for f in "$SYSTEM_SRC/systemd/system/"*; do
    install_file "$f" "/etc/systemd/system/$(basename "$f")"
done
sudo systemctl daemon-reload
sudo systemctl enable t2bce-audio.service

# polkit rules
for f in "$SYSTEM_SRC/polkit-1/"*; do
    install_file "$f" "/etc/polkit-1/rules.d/$(basename "$f")"
done

# ananicy
for f in "$SYSTEM_SRC/ananicy.d/"*; do
    install_file "$f" "/etc/ananicy.d/$(basename "$f")"
done

# scripts
for f in "$SYSTEM_SRC/scripts/"*; do
    sudo install -m 755 "$f" "/usr/local/bin/$(basename "$f")"
    echo "  -> /usr/local/bin/$(basename "$f")"
done

echo ""

# --------------------------------------------------------
# Rebuild initramfs (blacklists need to be baked in)
# --------------------------------------------------------
echo "[3/3] Rebuilding initramfs for linux-t2..."
sudo mkinitcpio -p linux-t2

echo ""
echo "Done. Reboot to apply all changes."
