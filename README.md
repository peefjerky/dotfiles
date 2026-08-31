# dotfiles

```
 ___  ___  ___  ___  ___  ___  ___  ___  ___
|   ||   ||   ||   ||   ||   ||   ||   ||   |
| p || e || e || f || s || - || m || b || p |
|___||___||___||___||___||___||___||___||___|

  MacBook Pro 2020 (T2) -- CachyOS -- Hyprland -- caelestia
```

Personal system configuration for a MacBook Pro 16,2 (2020) running CachyOS
with the linux-t2 kernel and the **caelestia** Quickshell desktop.

---

## Hardware

    Machine   : MacBook Pro 16,2 (13", 2020)
    CPU       : Intel Core i5-1038NG7 (Ice Lake, 4C/8T, AVX-512 + VNNI)
    Chip      : Apple T2 Security Chip (BCE/VHCI audio + USB routing)
    Display   : eDP-1 @ 2560x1600, 226 PPI, scale 1.6 (-> 1600x1000 logical)
    GPU       : Intel Iris Plus Graphics (ICL GT2)
    Kernel    : 7.2.2-1-cachyos (t2bce driver stack)
    Distro    : CachyOS

---

## Stack

    Compositor  Hyprland 0.56.2, configured in Lua (not hyprland.conf)
    Shell       caelestia-shell 2.4.0 + caelestia-cli 1.1.2 on Quickshell 0.3.1
    Terminal    kitty
    Shell       fish + starship
    Theming     matugen, driven by caelestia's scheme.json
    Touch Bar   tiny-dfr
    Dictation   voxtype 1.0.0 (Parakeet TDT v3, local, CPU)

> **This replaced the previous dots-hyprland / illogical-impulse setup.**
> Nothing from that stack remains. If you are looking for the old `quickshell/ii`
> tree or the `hypr/custom/*.lua` layout it used, it is in the history, not here.

---

## What is in this repo

    config/               User configs (~/.config/)
      caelestia/          THE shell config -- see below. The heart of this repo.
      quickshell/caelestia/
                          Shadow tree over the packaged shell: symlinks to the
                          package, plus the Cmd+G notepad module and three
                          patched modules/drawers/ files. See below.
      hypr/               Hyprland Lua entry point + variables
      voxtype/            Local dictation: engine, VAD, replacements, OSD
      psd/                profile-sync-daemon -- browser profiles in tmpfs
      systemd/user/       User unit drop-ins (EasyEffects restart, app.slice oomd)
      fish/ kitty/        Shell and terminal
      nvim/ mpv/ btop/    Editor, player, monitor
      cava/ easyeffects/  Audio visualiser and speaker DSP
      alacritty/ herdr/ yt-x/ spicetify/
      starship.toml, thorium-flags.conf, mimeapps.list

    local/                ~/.local/ -- things that are actual work, not installed files
      bin/extract-here    Archive extractor wired to Thunar via mimeapps.list
      bin/voxtype-submap  Hyprland Lua-dispatch shim for voxtype's submaps
      bin/projector       Drives a Moonlight session on the EO9022 projector
      share/voxtype/quickshell/
                          voxtype's OSD, retargeted at caelestia's theme

    system/               Root-owned files. Applied by install.sh with sudo.
      modprobe.d/         T2 audio load order, hid_apple, Touch Bar autodim
      tiny-dfr/           Touch Bar daemon config
      ananicy.d/          Process priority overrides
      udev/rules.d/       T2 audio wake rule
      systemd/system/     t2bce-audio.service, appletbdrm-rebind.service
      scripts/            t2-pci-wake.sh, t2bce-audio-load.sh, appletbdrm-rebind,
                          voxtype-osd-restore
      psd/browsers/       Thorium and Zen definitions psd does not ship
      sddm/               Wayland greeter drop-in -- parked, see the file header
      pacman.d/hooks/     Pacman hooks (voxtype OSD re-theme, ...)
      fonts/              Endless.ttf
      t2bce-migrate.sh    apple-bce -> t2bce initramfs migration for 7.2.0

    packages/
      pacman-explicit.txt   Explicitly installed pacman packages
      aur-foreign.txt       AUR / foreign packages
      aur-pending.txt       AUR packages considered but not installed, with reasons
      SYSTEM-NOTES.md       Hardware facts worth not re-deriving
      T2-TUNING.md          The long-form tuning log for this machine
      papirus-accent/       Icon-theme accent sync (sudoers rule + helper)

    DICTATION.md          Build brief and implementation log for voxtype
    CASTING.md            Casting to a TV/projector: Sunshine + Moonlight, and why
                          Miracast and AirPlay are dead ends on this hardware

---

## caelestia

caelestia ships its config in `/etc/xdg/quickshell/caelestia/`, which is
**package-owned and overwritten on every update**. Nothing in this repo edits it
in place. Most customisation goes through the two extension points caelestia
provides; the notepad needs to live inside the shell's own process, so it uses a
symlink shadow tree instead (see Notepad below):

    config/caelestia/hypr-user.lua    Loaded last by ~/.config/hypr/hyprland.lua.
                                      Monitor scale, hyprpm, plugin config.
    config/caelestia/hypr-vars.lua    Loaded first -- variable/keybind overrides
                                      that must land before caelestia's modules.
    config/caelestia/custom/*.lua     Scrolling layout, rules, input, animations,
                                      border colours, keybinds.
    config/caelestia/shell.json       Shell settings (explorer, toasts, ...)
    config/caelestia/templates/       Rendered into ~/.local/state/caelestia/theme/
                                      on *every* scheme change. This is how
                                      non-caelestia apps get matugen colours.

### Shell customisation

`config/fish/` **is** a caelestia dots target -- `caelestia update` overwrites it.
Personal fish config belongs in `config/caelestia/user-config.fish`, which
caelestia's own `config.fish` sources last and never overwrites.

(`~/.config/hypr/` is a dots target too, for the same reason `hypr-user.lua` and
`hypr-vars.lua` live under `caelestia/`.)

### Templates

`caelestia/utils/theme.py: apply_user_templates()` renders every file in
`~/.config/caelestia/templates/` on each scheme change, unconditionally. Three
live here:

    sddm-theme.conf      SDDM login theme colours
    zen-userChrome.css   Zen browser chrome, symlinked into the Zen profile
    zathurarc            Zathura PDF viewer colours

Syntax is `{{ colourname.form }}` where form is `hex` / `hexalpha` / `rgb` /
`rgbalpha`, plus `{{ mode }}`.

### Notepad

`config/quickshell/caelestia/modules/notepad/` is a module **inside** caelestia's
own shell, not a separate process. `~/.config/quickshell/caelestia/` shadows the
packaged `/etc/xdg/quickshell/caelestia/` in Quickshell's search path: everything
there is a symlink back to the package except this module and three patched
`modules/drawers/` files. That gets the notepad into caelestia's own `BlobGroup`,
so it merges with the launcher and sidebar the way caelestia's own panels do.

Run `modules/notepad/install.sh` to build the shadow tree, and re-run it after a
`caelestia-shell` upgrade -- it refuses to touch anything if the patches no longer
apply cleanly. `CAELESTIA-BLOBS.md` in that directory documents the SDF blob
renderer it depends on.

---

## T2-specific notes

### Audio -- use the Default profile

The T2 card must run PipeWire's **`Default`** profile. `pro-audio` runs no UCM,
so the amplifier never turns on and the speakers are silent at any volume.

The previous version of this repo shipped `wireplumber/` and `pipewire/` configs
forcing `pro-audio` with `api.acp.auto-profile=false`. **Those are deliberately
gone.** Do not restore them.

Load order is still worked around, because the T2 firmware sometimes fails to
expose the Speaker/Codec subdevices before `t2bce_audio` probes:

  1. `t2bce_audio` blacklisted from autoload (`modprobe.d/t2-audio-late-load.conf`)
  2. `t2bce-audio.service` loads it after `local-fs.target`
  3. `snd_soc_avs` blacklisted (`modprobe.d/t2-audio-fix.conf`)

### Touch Bar

`tiny-dfr` drives the strip. Two things matter:

- `ActiveBrightness` in `tiny-dfr/config.toml` is **inert on Intel T2**. It is a
  0-255 curve for Apple Silicon's `display-pipe` backlight; `hid_appletb_bl` here
  exposes exactly three steps (off / dim / max) and sits on max.
- Level 1 ("dim") is PWM'd and visibly flickers, and **two** things dim the bar.
  `modprobe.d/hid-appletb.conf` sets `autodim=N`, which disables the *driver's*
  timer -- necessary but not sufficient. **tiny-dfr runs its own idle timer** and
  writes the backlight directly on constants hardcoded in `src/backlight.rs`
  (`DIMMED_BRIGHTNESS = 1`, 30s dim / 60s off) with no config key for any of
  them, on master as well as 0.3.2.

  `DIMMED_BRIGHTNESS = 1` is right on Apple Silicon, where `display-pipe` is a
  0-255 backlight. On Intel T2, where `hid_appletb_bl` has only 0/1/2, it selects
  the one broken step. `packages/tiny-dfr-t2/` rebuilds tiny-dfr with it set to
  2, so "dim" is simply max: no flicker, 60s power-off untouched.

- **The bar is dark after some boots.** `appletbdrm` races the BCE virtual USB HCI
  (`apple_bce` before 7.2.0, `t2bce_vhci` since) and its probe times out:

      appletbdrm 5-6:2.1: [drm] *ERROR* Failed to send message (-110)
      appletbdrm 5-6:2.1: probe with driver appletbdrm failed with error -110

  No DRM card is created, so udev never tags `dev-tiny_dfr_display.device`, so
  `tiny-dfr.service` -- which `BindsTo=` it -- is cancelled 90s later. Nothing is
  wrong with tiny-dfr; it was never allowed to start. `appletbdrm-rebind.service`
  writes the interface name back to the driver's `bind` file inside that window;
  the retry succeeds. To fix a live session by hand:

      echo 5-6:2.1 | sudo tee /sys/bus/usb/drivers/appletbdrm/bind
      sudo systemctl start tiny-dfr

  Never `unbind` the USB *device* -- that leaves the Touch Bar dead until reboot.

### Suspend and hibernate

Suspend works **only through systemd** (`systemctl suspend`). `rtcwake -m mem`
bypasses `sleep.target` and hangs. Sleep hooks must live in
`/usr/lib/systemd/system-sleep/` -- systemd 261 silently ignores
`/etc/systemd/system-sleep/`.

Swap is a **20G swapfile with zswap**, not zram. This is a deliberate departure
from CachyOS's zram-only default: hibernate needs a real swap device, and a
swapfile under zram causes LRU inversion. Never add both.

### Keyboard modifier mapping

`modprobe.d/hid_apple.conf` sets **only** `fnmode=2`. Nothing swaps modifiers --
not the kernel, not Hyprland (`kb_options` is unset; `hyprctl getoption` reports
`set: false`). hid-apple's default already gives the mapping the keybinds want:

    physical   [fn] [control] [option] [command] [space]
    emits            CTRL       ALT      SUPER

So "Cmd" in every bind means the physical Command key. `swap_opt_cmd=1` -- which
this repo shipped for a while -- moves SUPER one key left onto Option and pushes
ALT onto Command. That is the PC key *order* (ctrl/super/alt) but not the labels,
and it makes every SUPER bind fire from the wrong key.

hid_apple loads from the **initramfs** here (the BCE stack — `t2bce_core` since
7.2.0, `apple_bce` before it — at ~1.08s, just after `Run /init`), so this file is baked into the image: `sudo limine-mkinitcpio`
after changing it. Both params are also live-writable under
`/sys/module/hid_apple/parameters/` and take effect on the next keypress.

---

## Dictation

`voxtype` with **Parakeet TDT 0.6B v3 int8**, entirely local, CPU-only. int8
because this CPU has `avx512_vnni` -- quantised inference is the hardware fast
path here, not a compromise. Full build log in `DICTATION.md`.

    Super + Ctrl + X    toggle
    F9 (hold)           push-to-talk
    F12                 cancel / escape a stuck submap

`[audio] pause_media = true` pauses MPRIS players while recording and resumes
after. Not a nicety: this mic sits ~11 dB above its noise floor, so anything
playing bleeds in, and both Whisper and Parakeet hallucinate text on the result.
Since voxtype 1.0.0 this talks D-Bus directly -- `playerctl` is no longer a
dependency, and the resume bug it caused (Omarchy #6029) went with it.

Two things that are **not** upstream's recommended setup, because upstream's is
wrong on this machine:

- `voxtype setup compositor hyprland` must **not** be run. It writes a `conf.d/`
  drop-in that nothing sources (this config is Lua) and its hooks call
  `hyprctl dispatch submap <name>`, which is a syntax error when `hyprctl
  dispatch` evaluates Lua. The submaps are defined in `custom/keybinds.lua` and
  driven through `local/bin/voxtype-submap`.
- `[vad] backend = "auto"` resolves to Energy VAD, which this quiet mic defeats.
  It is pinned to the Silero model instead.

---

## Browser profiles in RAM

`profile-sync-daemon` keeps browser profile directories on tmpfs and rsyncs them
back to disk periodically and on exit -- fewer small writes to the SSD, faster
profile reads. `config/psd/psd.conf` selects which browsers are managed.

psd ships definitions for the mainstream browsers but not for either of the ones
used here, so `system/psd/browsers/` adds them. Both exist because of the same
trap: psd refuses to sync a browser it sees running, via `pgrep -x`, and both
`/usr/bin/thorium-browser` and `/usr/bin/zen-browser` are wrapper scripts whose
real process name differs from the wrapper's. `PSNAME` has to name what actually
shows up in `/proc/PID/comm` (`thorium`, `zen-bin`) or the sync silently never
happens. Zen additionally needs `profiles.ini` parsed with quoting intact -- its
profile directory names contain spaces and parentheses.

Only `~/.config/thorium` is synced; the ~2 GB of `~/.cache/thorium` is left on
disk deliberately, since it is regenerable and would be pure overlay waste.

---

## Installation

### Requirements

- CachyOS (or Arch) with the linux-t2 kernel
- `caelestia-shell` + `caelestia-cli`
- `yay` for AUR packages

### Steps

    git clone https://github.com/peefjerky/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    bash install.sh

`install.sh` symlinks `config/` entries into `~/.config/` and applies `system/`
files with sudo. It skips anything that already exists and is not a symlink, so
back up first.

### apply-system.sh

> Initramfs note: `linux-cachyos` ships no `/etc/mkinitcpio.d` preset -- only
> `linux-cachyos-lts` does -- and boot entries are managed by
> `limine-mkinitcpio-hook`. So `mkinitcpio -P` rebuilds the **LTS** image and
> leaves the running kernel's untouched. Use `sudo limine-mkinitcpio`. The audio
> blacklists do not need it either way: those modules are not loaded from the
> initramfs.

    bash apply-system.sh

**Run this after changing anything under `system/`.** It is the root-owned half
of `install.sh` on its own -- modprobe blacklists, tiny-dfr, ananicy rules, udev,
systemd units, `system/scripts/` into `/usr/local/bin`, and the pacman hooks.
`install.sh` calls it rather than duplicating the logic.

The pacman hook it installs (`95-voxtype-osd.hook`) is what keeps the themed
voxtype OSD alive: on every `voxtype-bin` upgrade it re-runs
`voxtype setup quickshell` to pull upstream's new QML, overlays this repo's
`local/share/voxtype/quickshell/` on top, and restarts the daemon.

### Packages

    sudo pacman -S --needed - < packages/pacman-explicit.txt
    yay -S --needed - < packages/aur-foreign.txt

---

## Backup

`backup.sh` rsyncs personal data, keys and a full `~/.config` snapshot to an
external drive. It is **not** a repo sync -- it does not update this repo.

    bash backup.sh /run/media/peefjerky/YOUR_DRIVE

---

## License

Do whatever you want with this. No warranty.
