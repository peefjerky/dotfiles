#!/usr/bin/env bash
# backup.sh -- rsync important data to an external drive
#
# Usage:
#   bash backup.sh /run/media/peef/MY_DRIVE
#
# Mount your drive first (it will appear under /run/media/peef/<label>
# or /mnt/<label> depending on how you mount it).

set -e

if [ -z "$1" ]; then
    echo "Usage: bash backup.sh <mount-point>"
    echo "Example: bash backup.sh /run/media/peef/BACKUP_SSD"
    exit 1
fi

DEST="$1/peef-backup-$(date +%Y-%m-%d)"
echo "==> Destination: $DEST"
mkdir -p "$DEST"

rsync_it() {
    local label="$1"
    local src="$2"
    local dst="$3"
    echo ""
    echo "--- $label ---"
    rsync -avhP --delete \
        --exclude='.cache/' \
        --exclude='node_modules/' \
        --exclude='.git/' \
        "$src" "$dst"
}

# Personal data
rsync_it "Documents"      ~/Documents/                 "$DEST/Documents/"
rsync_it "Pictures"       ~/Pictures/                  "$DEST/Pictures/"
rsync_it "Videos"         ~/Videos/                    "$DEST/Videos/"
rsync_it "do_not_delete"  ~/Projects/do_not_delete/    "$DEST/do_not_delete/"
rsync_it "Projects"       ~/Projects/                  "$DEST/Projects/"

# Credentials and keys (no --delete to avoid accidents)
echo ""
echo "--- SSH keys ---"
rsync -avhP ~/.ssh/ "$DEST/ssh/"
chmod 700 "$DEST/ssh"
chmod 600 "$DEST/ssh/"* 2>/dev/null || true

echo ""
echo "--- GPG keys ---"
rsync -avhP ~/.gnupg/ "$DEST/gnupg/"
chmod 700 "$DEST/gnupg"

# Browser profiles (contain bookmarks, history, saved passwords)
rsync_it "Zen Browser"    ~/.zen/                      "$DEST/zen/"
rsync_it "Thunderbird"    ~/.thunderbird/               "$DEST/thunderbird/"

# Dotfiles repo itself
rsync_it "dotfiles"       ~/dotfiles/                  "$DEST/dotfiles/"

# Full ~/.config snapshot (for anything not in the dotfiles repo)
echo ""
echo "--- Full .config snapshot ---"
rsync -avhP --delete \
    --exclude='.cache/' \
    --exclude='thorium/' \
    --exclude='chromium/' \
    --exclude='google-chrome/' \
    --exclude='content_shell/' \
    --exclude='chromium-headless/' \
    "$HOME/.config/" "$DEST/config-full/"

echo ""
echo "==> Backup complete: $DEST"
du -sh "$DEST"
