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
echo "[1/4] Symlinking user configs..."

for entry in "$CONFIG_SRC"/*/; do
    name="$(basename "$entry")"
    # systemd is handled file-by-file below: symlinking the whole directory
    # would replace ~/.config/systemd, which holds units this repo does not own.
    [ "$name" = "systemd" ] && continue
    dst="$CONFIG_DST/$name"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "  SKIP $name (exists and is not a symlink -- back it up first)"
        continue
    fi
    ln -sfn "$entry" "$dst"
    echo "  -> $name"
done

# systemd user drop-ins, copied individually rather than symlinked.
if [ -d "$CONFIG_SRC/systemd/user" ]; then
    while IFS= read -r f; do
        rel="${f#$CONFIG_SRC/systemd/user/}"
        mkdir -p "$CONFIG_DST/systemd/user/$(dirname "$rel")"
        cp "$f" "$CONFIG_DST/systemd/user/$rel"
        echo "  -> systemd/user/$rel"
    done < <(find "$CONFIG_SRC/systemd/user" -type f)
    systemctl --user daemon-reload || true
fi

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
echo "[2/4] Applying system configs (requires sudo)..."

SYSTEM_SRC="$DOTFILES/system"

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

# --------------------------------------------------------
# ~/.local -- scripts and the voxtype OSD override
# --------------------------------------------------------
if [ -d "$DOTFILES/local" ]; then
    echo "[3/4] Installing ~/.local files..."
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
    for f in "$DOTFILES/local/bin/"*; do
        [ -f "$f" ] || continue
        install -m 755 "$f" "$HOME/.local/bin/$(basename "$f")"
        echo "  -> ~/.local/bin/$(basename "$f")"
    done
    for f in "$DOTFILES/local/share/applications/"*; do
        [ -f "$f" ] || continue
        install -m 644 "$f" "$HOME/.local/share/applications/$(basename "$f")"
        echo "  -> ~/.local/share/applications/$(basename "$f")"
    done
    # voxtype's OSD tree. `voxtype setup quickshell` overwrites this directory,
    # so re-run install.sh after a voxtype update to put the overrides back.
    if [ -d "$DOTFILES/local/share/voxtype/quickshell" ]; then
        mkdir -p "$HOME/.local/share/voxtype"
        cp -r "$DOTFILES/local/share/voxtype/quickshell" "$HOME/.local/share/voxtype/"
        echo "  -> ~/.local/share/voxtype/quickshell"
    fi
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo ""
fi

# --------------------------------------------------------
# Rebuild initramfs (blacklists need to be baked in)
# --------------------------------------------------------
echo "[4/4] Rebuilding initramfs (blacklists must be baked in)..."
# -P does every installed preset. The old `-p linux-t2` was hard-coded and fails
# outright on this machine, which runs linux-cachyos.
sudo mkinitcpio -P

echo ""
echo "Done. Reboot to apply all changes."
