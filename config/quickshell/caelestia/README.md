# Shadowed caelestia config

This directory **overrides** `/etc/xdg/quickshell/caelestia/`. Quickshell searches
`<xdg dir>/quickshell/<name>/shell.qml` and `~/.config` comes before `/etc/xdg`, so
`qs -c caelestia` — which is how caelestia's shell is launched — loads this tree
instead of the packaged one.

Almost everything here is a **symlink** into the packaged install, so package updates
land automatically. Only these are real files:

| path | why |
|---|---|
| `modules/notepad/` | the Cmd+G notepad, added as a panel |
| `modules/notepad/install.sh` | builds this whole tree; re-run after a caelestia upgrade |
| `modules/notepad/patches/` | the three hunks below, as `diff -u` files |
| `modules/drawers/ContentWindow.qml` | **patched** — adds the notepad's blob to the shared `BlobGroup` |
| `modules/drawers/Panels.qml` | **patched** — instantiates the notepad panel |
| `modules/drawers/Regions.qml` | **patched** — adds the notepad to the input mask |

Scriptable: `qs -c caelestia ipc call notepad {toggle,open,close,isOpen,save,get,set}`.

## Why the notepad lives here rather than in its own Quickshell config

It used to be standalone (`~/.config/caelestia/custom/notepad/`, `qs -p …`), on its own
Wayland layer surface above caelestia's. It rendered fine but could never look right at
the bottom edge: caelestia's border casts a `MultiEffect` shadow **inward into the border
hole**, and a separate translucent surface sitting on top of that shadow transmits ~15%
of it as a dark band. Caelestia's own panels have no band because they live inside the
same flattened silhouette — a merged blob has no internal edge, so no shadow is drawn at
the seam. That is not reproducible from another process.

Being in-process also gets, for free, the things that were previously impossible:
real blob merging with the launcher/sidebar/popouts, `deformMatrix` plumbing, and
caelestia's own `wallLuminance`-corrected colours.

See `modules/notepad/CAELESTIA-BLOBS.md` for how the blob system actually works.

## Maintaining this across caelestia updates

Run the installer. It is the source of truth for how this tree is built, and it is
safe to run at any time — running it twice changes nothing:

```sh
~/.config/quickshell/caelestia/modules/notepad/install.sh --check   # verify only
~/.config/quickshell/caelestia/modules/notepad/install.sh           # verify, then install
~/.config/quickshell/caelestia/modules/notepad/install.sh --revert  # move the tree aside
pkill -x qs; qs -c caelestia -n -d                                  # restart the shell
```

A `caelestia-shell` upgrade replaces `/etc/xdg` only, so `modules/notepad/` always
survives it. Two things can go stale, and the installer fixes both: upstream adds a
file this tree has no symlink for, and upstream edits one of the three patched files
so the copies here are built on the old version.

`--check` refuses to install rather than half-applying. It verifies:

- the patches still apply to the *current* packaged files — rehearsed for real in a
  temp dir, so the merged result exists and can be checked, then parsed with
  `qmlformat` (differentially: a file that already failed to parse before the patch
  is not blamed on the patch);
- every caelestia property the notepad reads still exists — `nonAnimHeight`,
  `shouldBeActive`, `nonAnimWidth`, the `Panels` aliases, `PanelBg`, `blobGroup`,
  `focusGrab`, `Regions.R`. This is the check that matters most: the notepad reaches
  into caelestia's panels for its sizing, and a renamed property there is a silent
  `NaN` at runtime, not a load error;
- the packaged version against the one the patches were cut from (a warning, since
  the dry run above is the real test), and any new upstream entries.

The patches themselves live in `modules/notepad/patches/`. To re-cut them after
editing a patched file by hand:

```sh
cd ~/.config/quickshell/caelestia
for f in ContentWindow.qml Panels.qml Regions.qml; do
    diff -u /etc/xdg/quickshell/caelestia/modules/drawers/$f modules/drawers/$f \
        > modules/notepad/patches/$f.patch
done
```

## The patches, in full

**`Panels.qml`** — import `qs.modules.notepad as Notepad`, add `readonly property alias
notepad: notepad`, and instantiate the panel bottom-centred with `panels: root`. All the
sizing logic (stacking above the launcher, shrinking to clear the dashboard / sidebar /
utilities / bar popouts) lives in the notepad's own `Wrapper.qml` and reads those panels
through that one alias — nothing about caelestia's panels is changed to accommodate it.

**`ContentWindow.qml`** — import `qs.modules.notepad`; add a `PanelBg { panel:
panels.notepad; deformAmount: 0.1 }`; add `notepad.transform: Matrix4x4 { matrix:
notepadBg.deformMatrix }`; add `NotepadState.open` to `WlrLayershell.keyboardFocus` and
to `focusGrab.active`; clear it in `focusGrab.onCleared`.

**`Regions.qml`** — one `R` for the notepad, pinned to the bottom edge and sized to the
visible fraction, exactly like the launcher's. Without it the panel is not clickable.

## Reverting

```sh
~/.config/quickshell/caelestia/modules/notepad/install.sh --revert
pkill -x qs; qs -c caelestia -n -d
```

Caelestia falls straight back to the packaged config. The notepad disappears; nothing
else changes. The tree is moved to `caelestia.off-<timestamp>`, not deleted, so
re-installing is a `mv` back.
