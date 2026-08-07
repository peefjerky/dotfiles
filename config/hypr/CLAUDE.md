# Hyprland config (illogical-impulse / dots-hyprland, Hyprland 0.55+ Lua)

This is a **Lua-based** Hyprland config (`configProvider: lua`, confirmed via `hyprctl systeminfo`).
Hardware: MacBook Pro 2020 (T2 chip, `linux-t2` kernel), internal display `eDP-1` @ 2560x1600 @226 PPI.

## Structure

- `hyprland.lua` — entrypoint. `require()`s everything else. Don't edit unless restructuring requires/order.
- `hyprland/*.lua` — **defaults shipped by dots-hyprland**. Overwritten on dotfile updates. Don't edit.
- `custom/*.lua` — **user overrides, persist across updates**. All customization goes here.
  - `custom/general.lua` — monitor config, scrolling layout config, gestures, `kb_options`.
  - `custom/keybinds.lua` — extra keybinds (scrolling layout + hardware brightness keys).
  - `custom/env.lua`, `custom/execs.lua`, `custom/rules.lua`, `custom/variables.lua` — currently empty boilerplate, created automatically by `hyprland/services/create_custom_config.lua` if missing.
  - `custom/scripts/` — misc user scripts (`patch-gestures.sh`, `__restore_video_wallpaper.sh`, `update-vscodium-material-code.sh`).
- `LEGACY_CONFIG_ARCHIVE.md` — full content of all pre-Lua `.conf`/`.bak`/`.new`/`.old`/`.backup` files that were removed during cleanup (2026-06-14). Check here if an old setting needs to be recovered; nothing in it is live.

## Diagnostics

- `hyprctl configerrors` — shows live config errors (equivalent of the on-screen red error banner). **Always run this after editing Lua config.**
- `hyprctl reload config-only` — reload without other side effects.
- `hyprctl getoption <key>` — check the live value of a config option, e.g. `input:kb_options`.

## Current custom config state

**`custom/general.lua`:**
- `hl.monitor()`: eDP-1 @ 2560x1600@60, `scale = 1.6` (1.4 was tried first but isn't a valid scale step on this system — closest steps are 1.33/1.5/1.6; user settled on 1.6).
- Layout = `scrolling` (infinite horizontal tape of columns). `direction = "right"`.
- 3-finger horizontal swipe: pans the scrolling-layout tape via `action = "scroll_move"`. As of the 2026-06-14 dots-hyprland update, the default `{fingers=3, direction="swipe", action="move"}` (3-finger swipe = move window; was `{fingers=3, direction="horizontal", action="workspace"}` before) is `unset` using its `"swipe"` signature, then `{fingers=3, direction="horizontal", action="scroll_move"}` is registered. Re-check this signature after future dots-hyprland updates — see Gotchas below.
- `kb_options = "altwin:swap_alt_win"` — counters the **system-wide** `hid_apple` `swap_opt_cmd=1` (set in `/etc/modprobe.d/hid_apple.conf`), so the physical **Command key = SUPER**, physical **Option key = ALT**. If `swap_opt_cmd` is ever changed system-wide, this XKB option needs re-evaluating.

**`custom/keybinds.lua`:**
- Scrolling layout binds (`SUPER+ALT+...`): focus/swap columns, scroll tape, expel/consume/promote, fit view.
- Column resize: `SUPER+ALT+BracketLeft`/`BracketRight` = shrink/widen (`colresize ±0.1`), `SUPER+ALT+Backslash` = reset to 0.5. NOT bound to `SUPER+Semicolon`/`SUPER+Apostrophe` (default `splitratio`, dwindle-only) or `SUPER+ALT+0` (default `code:19` = move window to workspace group 10) — see Gotchas below for why.
- View fitting: `SUPER+ALT+Y` = `fit active` (expand focused column to fill view), `SUPER+ALT+SHIFT+Y` = `fit all` (fit all columns on screen). NOT `fit_into_view`/`fit expand` — see Gotchas below, version-dependent.
- `XF86KbdBrightnessUp/Down` → keyboard backlight; `SUPER + XF86KbdBrightnessUp/Down` → Touch Bar backlight (via `brightnessctl`).

## Gotchas / conventions learned

- Hyprland gestures are keyed by `(fingers, direction, mods, scale)`. **Same-signature re-registration does NOT replace a default** — it gets *shadowed* by the earlier-loaded default and the error reads "Previous X shadows new X". To actually override a default gesture: `hl.gesture({..., action="unset"})` with the **exact same signature as the default**, then register the new gesture. Getting the unset signature wrong throws `hl.gesture: Can't remove a non-existent gesture` (visible in `hyprctl configerrors`) — **dots-hyprland updates can silently change a default gesture's signature**, breaking a previously-working unset/override (happened 2026-06-14, see `custom/general.lua` note above). `direction = "swipe"` is a **wildcard** that shadows any more specific direction (e.g. `"horizontal"`) for the same finger count — if a default uses `"swipe"`, you must unset it with `"swipe"`, but your own override registration can then safely use a more specific direction like `"horizontal"` since nothing remains to shadow it.
- `hl.unbind("MOD + Key")` does **not** reliably remove default binds in this build — `hyprctl binds -j` keeps showing both the old and new bind on the same key even after a full `hyprctl reload`. Don't try to reuse a default key combo via `hl.unbind`; pick a different, non-colliding combo instead and verify with `hyprctl binds -j | jq '.[] | select(.modmask==<N> and .key=="<Key>")'` (collision = >1 result).
- Multiple binds on the same key combo all fire together — Hyprland doesn't dedupe/override by default. Two failure modes seen here:
  - **Visible error**: default `SUPER+Semicolon`/`SUPER+Apostrophe` → `hl.dsp.layout("splitratio ...")` is dwindle-only; under `scrolling` it throws `=[C]:-1: no such layoutmsg for scrolling` (shows in `hyprctl configerrors`, which surfaces *runtime* dispatch errors too, not just load errors). Avoided by binding resize to `SUPER+ALT+BracketLeft/Right` instead.
  - **Silent side effect**: default `SUPER+ALT+code:19` (raw keycode for the physical "0" key) → "move window to workspace group 10" is layout-agnostic, so it throws no error but co-fires with any keysym `"0"` bind on `SUPER+ALT`. A keysym bind and a `code:N` bind on the same physical key are separate registrations that both fire — `hyprctl binds -j` won't show them as obvious duplicates (the `code:N` one shows up with empty `key`/`keycode` fields). Avoided by binding "reset column width" to `SUPER+ALT+Backslash` instead of `SUPER+ALT+0`.
- No `kb_options` existed before; `hl.config({ input = {...} })` merges into the existing input table rather than replacing it.
- Prefer Hyprland/XKB-level config fixes (`kb_options`, `hl.config`) over system-level changes (kernel module params, initramfs rebuilds, reboots) when both achieve the same result — lower risk, instantly reversible, no reboot.
- `hyprctl dispatch` syntax in this Lua build is a full Lua expression string, e.g. `hyprctl dispatch 'hl.dsp.layout("colresize -0.1")'` — NOT the old `hyprctl dispatch layoutmsg "colresize -0.1"` CLI syntax, which produces a misleading Lua parse error.
- Scrolling layout `layoutmsg` commands are **version-dependent** — don't trust wiki/memory without checking `src/layout/algorithm/tiled/scrolling/ScrollingAlgorithm.cpp` for the installed tag (`hyprctl version`). On 0.55.4: valid top-level commands are `move`, `colresize`, `fit`, `focus`, `promote`/`consume`/`expel`/`consume_or_expel`, `swapcol` — **no** `fit_into_view` or `inhibit_scroll` (added later upstream). `fit` requires `ARGS[1]` ∈ {`active`, `all`, `toend`, `tobeg`, `visible`} — an unrecognized arg like `fit expand` matches the `fit` branch, does nothing, and returns `ok` (silent no-op, not an error). To check args for the running version: `gh api repos/hyprwm/Hyprland/git/refs/tags/vX.Y.Z` → resolve sha → `gh api repos/hyprwm/Hyprland/git/trees/<sha>?recursive=true` (with `-f recursive=true`) → find the blob sha → `gh api repos/hyprwm/Hyprland/git/blobs/<blobsha> --jq '.content' | base64 -d`.
- `promote`/`consume`/`expel` are real commands but depend on layout state (number of columns/windows) — `consume` with only one column returns `warning: no next column` and does nothing. That's expected behavior, not a binding bug; test with 2+ windows open.
- Quickshell overview (Command-key popup) window cells could overflow into the neighboring workspace cell under the `scrolling` layout (2026-06-15 fix). Root cause: for a column that's only partially on-screen (peeking in from the next workspace), Hyprland's `clients` JSON still reports the window's full, un-clipped `at`/`size`, so the overview rendered it at full size and it visually bled past the cell boundary. Fixed in `~/.config/quickshell/ii/modules/ii/overview/`: `OverviewWindow.qml` adds `visibleWidth`/`visibleHeight` properties (default = full `targetWindowWidth`/`targetWindowHeight`), uses them for the root `Item`'s `width`/`height` plus `clip: true`, and anchors the `ScreencopyView` top-left at the full target size so clipping crops rather than squishes; `OverviewWidget.qml` binds `visibleWidth`/`visibleHeight` on the `OverviewWindow` delegate to `Math.min(targetWindow*, root.workspaceImplicit* - *WithinWorkspaceWidget)` clamped to ≥0. Caveat: `~/.config/quickshell/ii/` is the dots-hyprland-shipped "ii" shell (same update-overwrite risk as `hyprland/*.lua`) — a future shell update could silently drop this fix; re-apply from this description if the overflow returns.
- Quickshell overview workspace cells are dynamically sized by content (2026-06-15 feature, same overwrite-risk caveat as above, in `~/.config/quickshell/ii/modules/ii/overview/OverviewWidget.qml`): a workspace whose scrolling-layout tape is wider than one screen gets a proportionally wider cell, and the row's other (idle) cells shrink to compensate, keeping the row's total width constant. Implementation: `getWorkspaceContentWidth(ws)` (sums non-floating windows' tape extent, via `getWorkspaceTapeOriginX(ws) = min(...windows' at[0])` — see scroll-invariance note below) → `getWorkspaceContentWidthRendered = contentWidth * root.scale` → `getNaturalCellWidth(ws) = max(workspaceImplicitWidth, contentWidthRendered)`. `getCellWidth(rowIndex, colIndex)`: if a row's total natural width exceeds `columns*workspaceImplicitWidth`, the excess is taken from idle cells (`natural == workspaceImplicitWidth`) down to a floor of `workspaceImplicitWidth*minCellWidthRatio` (0.5), split evenly; busy cells keep their *exact* natural width (no slack) unless idle cells hit the floor first, in which case remaining excess is split between busy cells proportional to natural width (causing clipping only in this extreme multi-busy-workspace case). The "exact natural width, no slack" part matters: an earlier version redistributed *by ratio* (weight = contentWidth/oneScreenWidth) which kept the row total exactly constant but left ~10-15% slack in the busy cell — visually, the workspace-number label (centered in the full, slack-including cell) ended up floating in dead space to the right of the bunched window thumbnails, disconnected-looking. Verified by adding a temporary debug `Timer`/`onXWithinWorkspaceWidgetChanged` `console.log` to `OverviewWidget.qml`, restarting via `killall qs quickshell; nohup qs -c ii > /tmp/qs.log 2>&1 &`, toggling the overview via `hyprctl dispatch 'hl.dsp.global("quickshell:overviewWorkspacesToggle")'`, and cross-checking logged `cellWidth`/`xWithin`/`targetW` numbers against `grim` screenshots cropped with `python3`+`PIL` — both removed after confirming the fix.
- Quickshell overview cell content used to "scroll" along with the live scrolling-layout viewport — scrolling the tape (e.g. via the `SUPER+ALT+Comma/Period` "move ±col" binds) shifted/hid windows inside the overview cell, leaving visible dead space (2026-06-15 fix, same file/caveat as above). Root cause: `hyprctl clients -j`'s `at[0]` is viewport-relative — when the tape scrolls, Hyprland shifts **every** window's `at[0]` in that workspace by the same delta (the viewport/"camera" stays conceptually fixed at screen x=0). The old `getWorkspaceTapeOriginX` computed `min(0, ...wins.map(w => w.at[0] - monitorLeft))` and `xWithinWorkspaceWidget` subtracted `monitorLeft` too — the `Math.min(0, ...)` zero-clamp meant the origin did **not** always shift by the same delta as the windows (it only tracked the shift once the leftmost window's relative `at[0]` went negative), so `xWithinWorkspaceWidget = at[0] - monitorLeft - origin` became scroll-position-dependent. Fixed by making the origin purely relative to the workspace's own windows, with no monitor offset and no clamp: `getWorkspaceTapeOriginX(ws) = Math.min(...wins.map(w => w.at[0]))`, `getWorkspaceContentWidth` similarly drops `monitorLeft` (`maxRight = Math.max(...wins.map(w => w.at[0] + w.size[0]))`), and the window delegate's `xWithinWorkspaceWidget = Math.max((windowData.at[0] - getWorkspaceTapeOriginX(ws)) * root.scale, 0)`. Since scrolling shifts every window's (and thus the origin's) `at[0]` by the identical delta, `at[0] - origin` is invariant — verified by logging `origin`/`content`/`xWithin` before and after `hyprctl dispatch 'hl.dsp.layout("move +col")'`: all three stayed numerically identical (e.g. `content=2224`, kitty `xWithin=215.25`) across three different scroll positions, while the raw `at[0]` values shifted together by -1435 each time.
  - This alone wasn't enough — `xWithinWorkspaceWidget`/`cellWidth` only affect *sizing/clipping* (`visibleWidth` etc.), not the window delegate's actual on-screen `x`. That comes from `OverviewWindow.qml`'s `initX` (`x: initX` binding), which independently computed `Math.max((at[0] - monitorData.x - monitorData.reserved[0]) * widthRatio * scale, 0) + xOffset` — still the old monitor-relative, zero-clamped, scroll-dependent formula. Result: `cellWidth`/border were scroll-invariant (fixed above) but each window's *position* still tracked the live `at[0]`, so windows visually slid within a fixed-width cell as the tape scrolled, uncovering dead space on one side. Fixed by adding `property real tapeOriginX: 0` to `OverviewWindow.qml` and changing `initX` to `Math.max((at[0] - tapeOriginX) * widthRatio * scale, 0) + xOffset` (dropping the monitor-origin terms), then binding `tapeOriginX: root.getWorkspaceTapeOriginX(windowData?.workspace.id)` in the delegate in `OverviewWidget.qml` — making `initX` match `xWithinWorkspaceWidget` (for `widthRatio=1`, true on this single-monitor system). Verified visually: before the fix, a 2-window workspace cell showed thorium overlapping kitty plus ~94.5 render-units (≈151px) of dead space after kitty; after, both windows fill the cell edge-to-edge identically before and after `hl.dsp.layout("move +col")`.

## System performance & audio tuning (2026-08-06)

All changes below are outside the Hyprland Lua config but were made in the same session and are worth knowing.

### Audio — T2 BCE driver (linux-t2 7.1.5+)

linux-t2 7.1.5 switched from an HDA codec to `t2bce_audio`, a staging BCE (PCIe bridge) driver. BCE exposes **no HDA mixer controls**, so ACP profile probing always fails — the "Default" profile never appears. Fix: `~/.config/wireplumber/wireplumber.conf.d/52-apple-t2-audio.conf` forces `device.profile = "pro-audio"` for the Apple Audio Device, which bypasses ACP probing entirely.

Active sinks under pro-audio:
- `alsa_output.pci-0000_e6_00.3.pro-output-0` — **internal speakers** (use this as default output)
- `alsa_output.pci-0000_e6_00.3.pro-output-2` — **headphone jack** (Codec Output; auto-switch when plugged in)
- `alsa_output.pci-0000_e6_00.3.pro-output-4` — Bridge Loopback (internal T2 routing pipe, ignore)

EasyEffects autoloads preset `mbp` for `pro-output-0` — config at `~/.config/easyeffects/autoloading/output.json`. WP saved state at `~/.local/state/wireplumber/default-profile` set to `pro-audio`.

The udev rules at `/etc/udev/rules.d/91-92` (apple-t2 package) try to set `ACP_PROFILE_SET` via a sed pattern that doesn't match the BCE card name — harmless under pro-audio since no ACP profile-set is consulted. `/etc/udev/rules.d/93-apple-t2-audio-fix.rules` was a debugging artifact (pointed to `apple-t2x2.conf`); **remove it** if still present. Similarly remove `/usr/share/alsa-card-profile/mixer/profile-sets/apple-t2-audio.conf` and `/usr/share/alsa-card-profile/mixer/paths/t2-headphones-nojack.conf` if present.

### Audio — Bluetooth A2DP latency

`~/.config/wireplumber/wireplumber.conf.d/60-bluetooth-latency.conf` sets `node.latency = "2048/48000"` on all `bluez_output.*` nodes. Drops BT pipeline wake-ups from ~94/sec (512 quantum) to ~23/sec (2048 quantum), cutting idle CPU overhead for connected BT headphones.

### Audio — PipeWire quantum

`~/.config/pipewire/pipewire.conf.d/99-lowlatency.conf`: `quantum=512`, `min-quantum=32`, **no `max-quantum`**. Omitting `max-quantum` is intentional — lets the BT driver use its native ~2048 quantum instead of being capped at 512.

### Performance — misc system tweaks

- **THP**: `/etc/sysctl.d/99-thp.conf` — `transparent_hugepage=madvise`. Lets memory-hungry apps opt in without system-wide overhead.
- **ananicy-cpp**: `/etc/ananicy.d/ananicy.conf` — `check_freq=300`, `cgroup_load=false`. Lower scan rate; cgroup load disabled (was interfering with CPU freq).
- **tiny-dfr**: `/etc/tiny-dfr/config.toml` — `AdaptiveBrightness=false`. Was causing periodic CPU spikes from brightness polling.

### LibrePods

AirPods integration app (ear detection, auto-pause, battery). Binary at `/home/peef/Apps/librepods/linux/build/applinux`. Autostart via `~/.config/autostart/applinux.desktop` (XDG autostart, picked up by Hyprland on login).

## Companion daemons (NOT part of the Lua migration — separate native configs)

These are read directly by their own binaries, not by `hyprland.lua`:
- `hypridle.conf` — idle daemon
- `hyprlock.conf` + `hyprlock/colors.conf` — lock screen
- `hyprpaper.conf` — wallpaper daemon
- `hyprsunset.conf` — blue-light filter

## Related files outside this directory

- `~/.config/quickshell/ii/shell.qml` — Quickshell (the "ii" shell). Has `//@ pragma Env QT_SCALE_FACTOR=1` since the monitor scale (1.4) is handled by the compositor; don't double-scale.
- `~/.config/thorium-flags.conf` — forces `--ozone-platform-hint=wayland` so Thorium scales correctly under Wayland (was commented out until 2026-06-14, causing Thorium to run under XWayland and get blurry-upscaled to 1.6x via `xwayland.force_zero_scaling`). Do **not** add `--gtk-version=4` here: combined with native-Wayland ozone, GTK4's settings-portal code null-derefs (`SIGSEGV`) when `org.freedesktop.portal.Desktop` is unreachable — which it is on this system because `graphical-session.target` is never activated (Hyprland launched directly via SDDM without a session-manager wrapper like UWSM that binds to it; `systemctl --user start graphical-session.target` is refused as manual-start-only). GTK3 (the default, no `--gtk-version` flag) doesn't hit this crash. Fixing the portal/session-target gap properly would need a UWSM-based session setup — bigger, session-wide change, not done.
