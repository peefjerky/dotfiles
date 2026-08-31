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

# yt-x renders fzf previews through a shared helper it generates into its cache.
# Ours replaces it (upstream's round-trips the terminal, which corrupts fzf's
# input -- see the header of config/yt-x/fzf-preview.sh). yt-x only writes that
# file when it is missing, and its cache sweep is `find -type f`, which does not
# match a symlink, so pointing it at the repo copy survives both.
if [ -f "$CONFIG_SRC/yt-x/fzf-preview.sh" ]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/yt-x/previews/text"
    ln -sfn "$CONFIG_SRC/yt-x/fzf-preview.sh" \
        "${XDG_CACHE_HOME:-$HOME/.cache}/yt-x/previews/text/fzf-preview.sh"
    echo "  -> yt-x fzf-preview.sh (into the preview cache)"
fi

echo ""

# --------------------------------------------------------
# System configs (/etc/, /usr/local/bin/)
# --------------------------------------------------------
echo "[2/4] Applying system configs (requires sudo)..."
bash "$DOTFILES/apply-system.sh"

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
