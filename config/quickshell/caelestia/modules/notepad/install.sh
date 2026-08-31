#!/usr/bin/env bash
#
# Installs the Cmd+G notepad into caelestia's shell, and re-installs it after a
# caelestia-shell upgrade.
#
# Nothing here touches /etc/xdg. Quickshell resolves a config name against every
# XDG config dir in order, and ~/.config wins over /etc/xdg -- so a tree at
# ~/.config/quickshell/caelestia/ shadows the packaged one and `qs -c caelestia`
# (how caelestia launches its shell) loads it instead. Everything in that tree is a
# symlink back to the package except this module and three drawers files that carry
# the integration hooks, which are copied and patched.
#
# A package upgrade replaces /etc/xdg only. What it can break is exactly two things:
# upstream adds a file that this tree has no symlink for, or upstream edits one of
# the three patched files so the copies here go stale. Re-running this fixes both.
#
#   ./install.sh --check     preflight only, touches nothing, exits 1 if unsafe
#   ./install.sh             preflight, then install
#   ./install.sh --revert    move the shadow tree aside; caelestia falls back to
#                            the packaged config
#
# After installing, restart the shell:  pkill -x qs; qs -c caelestia -n -d

set -uo pipefail

SRC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
UPSTREAM=${UPSTREAM:-/etc/xdg/quickshell/caelestia}
TARGET=${TARGET:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}

# The three files the mod has to modify, and the drawers dir they live in.
PATCHED=(ContentWindow.qml Panels.qml Regions.qml)

# Version the patches were cut against. A mismatch is a warning, not an error --
# the patch dry-run below is the real test.
PINNED_VERSION="caelestia-shell 2.3.0-1"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
fail() { red "  FAIL  $*"; failed=$((failed + 1)); }
warn() { yellow "  WARN  $*"; }
ok() { green "  ok    $*"; }

failed=0

# ---------------------------------------------------------------- preflight ---
#
# Two independent things can break, and both are checked:
#
#   1. The patches no longer apply -- upstream edited one of the three files.
#      `patch --dry-run` is the authority on this; nothing is written.
#   2. The patches apply but the notepad's own QML reads something that no longer
#      exists. The notepad reaches into caelestia's panels for sizing (how tall the
#      launcher is, whether the dashboard is open, how wide a bar popout is), and a
#      renamed property there is a silent NaN at runtime, not a load error. Those
#      reads are listed below and grepped for.

check() {
    echo "notepad mod preflight"
    echo "  source:   $SRC"
    echo "  upstream: $UPSTREAM"
    echo "  target:   $TARGET"
    echo

    # -- the packaged shell is where we think it is
    if [[ -f $UPSTREAM/shell.qml ]]; then
        ok "packaged caelestia found"
    else
        fail "no $UPSTREAM/shell.qml -- is caelestia-shell installed?"
        return
    fi

    local version
    version=$(pacman -Q caelestia-shell 2>/dev/null)
    if [[ -z $version ]]; then
        warn "caelestia-shell not a pacman package; skipping version check"
    elif [[ $version == "$PINNED_VERSION" ]]; then
        ok "$version (patches were cut against this)"
    else
        warn "$version, patches were cut against $PINNED_VERSION"
    fi

    # -- this module is complete
    local f
    for f in Wrapper.qml NotepadState.qml Card.qml services/Store.qml; do
        [[ -f $SRC/$f ]] || fail "missing notepad source: $f"
    done
    for f in "${PATCHED[@]}"; do
        [[ -f $SRC/patches/$f.patch ]] || fail "missing patch: patches/$f.patch"
    done
    ((failed)) && return
    ok "notepad module and patches present"

    # -- rehearse the whole merge in a temp dir. Not `patch --dry-run`: doing it for
    #    real on a throwaway copy also produces the merged file, which then gets fed
    #    to a QML parser below. That is the difference between "the patch applied"
    #    and "the result is loadable".
    local tmp
    tmp=$(mktemp -d)
    for f in "${PATCHED[@]}"; do
        cp "$UPSTREAM/modules/drawers/$f" "$tmp/$f"
        if patch --silent --forward "$tmp/$f" < "$SRC/patches/$f.patch" > "$tmp/$f.log" 2>&1; then
            ok "patch applies: $f"
        else
            fail "patch no longer applies: $f -- upstream changed it"
            sed 's/^/        /' "$tmp/$f.log"
        fi
    done

    # Differential, not absolute: qmlformat exits nonzero on some of caelestia's own
    # files as they ship (it is a formatter, and its parser is stricter than the
    # engine's). Only a file that parsed *before* the patch and not after is ours.
    if command -v qmlformat >/dev/null; then
        for f in "${PATCHED[@]}"; do
            qmlformat "$UPSTREAM/modules/drawers/$f" >/dev/null 2>&1 || continue
            if qmlformat "$tmp/$f" >/dev/null 2>&1; then
                ok "merged $f parses"
            else
                fail "merged $f no longer parses as QML"
            fi
        done
    else
        warn "qmlformat not found; skipping the parse check"
    fi
    rm -rf "$tmp"

    # -- caelestia still exposes what the notepad reads
    #    "<file> <regex> <what it is used for>"
    local api=(
        "modules/drawers/Panels.qml|alias launcher: launcher|launcher panel, to stack above it"
        "modules/drawers/Panels.qml|alias dashboard: dashboard|dashboard panel, to shrink under it"
        "modules/drawers/Panels.qml|alias sidebar: sidebar|sidebar column, to narrow away from"
        "modules/drawers/Panels.qml|alias utilities: utilities|utilities dock, ditto"
        "modules/drawers/Panels.qml|alias popouts: popoutsWrapper.content|bar popouts, ditto"
        "modules/launcher/Wrapper.qml|property bool shouldBeActive|settled launcher height"
        "modules/dashboard/Wrapper.qml|property real nonAnimHeight|settled dashboard height"
        "modules/dashboard/Wrapper.qml|property bool shouldBeActive|dashboard open state"
        "modules/sidebar/Wrapper.qml|property bool shouldBeActive|sidebar open state"
        "modules/utilities/Wrapper.qml|property bool shouldBeActive|utilities open state"
        "modules/utilities/Wrapper.qml|Tokens.sizes.utilities.width|utilities width token"
        "modules/bar/popouts/Wrapper.qml|property real nonAnimWidth|settled popout width"
        "modules/drawers/ContentWindow.qml|component PanelBg: BlobRect|blob background for the panel"
        "modules/drawers/ContentWindow.qml|id: blobGroup|the shared BlobGroup to weld into"
        "modules/drawers/ContentWindow.qml|id: focusGrab|click-outside-to-close"
        "modules/drawers/Regions.qml|component R:|input mask entry"
    )
    local entry file pattern purpose
    for entry in "${api[@]}"; do
        IFS='|' read -r file pattern purpose <<< "$entry"
        if grep -qF -- "$pattern" "$UPSTREAM/$file" 2>/dev/null; then
            ok "api: $pattern"
        else
            fail "api gone: '$pattern' in $file -- notepad needs it for: $purpose"
        fi
    done

    # -- entries upstream added since this tree was built. Not an error: install
    #    symlinks them. Worth naming, because a missing symlink is the other way an
    #    upgrade breaks the shell, and it fails as a bare "module not installed".
    if [[ -d $TARGET ]]; then
        local new
        new=$(comm -23 <(cd "$UPSTREAM" && ls) <(cd "$TARGET" && ls))
        [[ -n $new ]] && warn "new upstream entries, install will symlink: ${new//$'\n'/ }"
        new=$(comm -23 <(cd "$UPSTREAM/modules" && ls) <(cd "$TARGET/modules" && ls))
        [[ -n $new ]] && warn "new upstream modules, install will symlink: ${new//$'\n'/ }"
    fi
}

# ------------------------------------------------------------------ install ---
#
# Reconciles rather than rebuilds: symlinks whatever is missing, re-copies and
# re-patches the three drawers files. Running it twice is a no-op. modules/notepad
# is never touched, so an install can't eat the thing it is installing.

link() {
    # $1 = path relative to the config root, symlinked to the packaged file
    local rel=$1
    [[ -L $TARGET/$rel ]] && return
    [[ -e $TARGET/$rel ]] && { warn "not a symlink, leaving alone: $rel"; return; }
    ln -s "$UPSTREAM/$rel" "$TARGET/$rel"
}

install_mod() {
    echo
    echo "installing"
    mkdir -p "$TARGET/modules/drawers"

    # Whole-directory symlinks, except the two dirs that hold real files.
    local p e
    for p in "$UPSTREAM"/*; do
        e=${p##*/}
        [[ $e == modules ]] || link "$e"
    done
    for p in "$UPSTREAM"/modules/*; do
        e=${p##*/}
        [[ $e == drawers ]] || link "modules/$e"
    done
    for p in "$UPSTREAM"/modules/drawers/*; do
        e=${p##*/}
        [[ " ${PATCHED[*]} " == *" $e "* ]] || link "modules/drawers/$e"
    done
    ok "symlinks reconciled"

    # The notepad itself, if this script is being run from outside the tree.
    if [[ $SRC != "$TARGET/modules/notepad" ]]; then
        rm -rf "$TARGET/modules/notepad"
        cp -r "$SRC" "$TARGET/modules/notepad"
        ok "notepad module copied in"
    else
        ok "notepad module already in place"
    fi

    # Fresh copies from the package, then patched. Copying first is what makes this
    # safe to re-run after an upgrade: the patch always lands on the new upstream,
    # never on last version's already-patched file.
    local f
    for f in "${PATCHED[@]}"; do
        rm -f "$TARGET/modules/drawers/$f"
        cp "$UPSTREAM/modules/drawers/$f" "$TARGET/modules/drawers/$f"
        if patch --silent "$TARGET/modules/drawers/$f" < "$SRC/patches/$f.patch"; then
            ok "patched $f"
        else
            red "  FAIL  patching $f -- restoring the packaged file"
            cp "$UPSTREAM/modules/drawers/$f" "$TARGET/modules/drawers/$f"
            return 1
        fi
    done

    # No parse check here: preflight already rehearsed this exact merge in a temp
    # dir and parsed the result. Repeating it would only re-run the same test.

    echo
    green "done. restart the shell:  pkill -x qs; qs -c caelestia -n -d"
}

# ------------------------------------------------------------------- revert ---

revert() {
    [[ -d $TARGET ]] || { echo "nothing to revert: $TARGET does not exist"; exit 0; }
    local off=$TARGET.off-$(date +%Y%m%d-%H%M%S)
    mv "$TARGET" "$off"
    green "moved aside: $off"
    echo "caelestia now loads $UPSTREAM. Restart: pkill -x qs; qs -c caelestia -n -d"
}

# --------------------------------------------------------------------- main ---

case ${1:-} in
    --revert) revert; exit 0 ;;
    --check)  check; echo; ((failed)) && { red "$failed check(s) failed -- installing would break caelestia"; exit 1; }
              green "safe to install"; exit 0 ;;
    "")       ;;
    *)        echo "usage: $0 [--check|--revert]"; exit 2 ;;
esac

check
echo
if ((failed)); then
    red "$failed check(s) failed -- refusing to install, nothing was touched"
    exit 1
fi
install_mod
