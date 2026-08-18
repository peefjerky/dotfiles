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
    Kernel    : 7.1.8-1-cachyos
    Distro    : CachyOS

---

## Stack

    Compositor  Hyprland 0.56.2, configured in Lua (not hyprland.conf)
    Shell       caelestia-shell 2.3.0 + caelestia-cli 1.1.2 on Quickshell 0.3.0
    Terminal    kitty
    Shell       fish + starship
    Theming     matugen, driven by caelestia's scheme.json
    Touch Bar   tiny-dfr
    Dictation   voxtype (Parakeet TDT v3, local, CPU)

> **This replaced the previous dots-hyprland / illogical-impulse setup.**
> Nothing from that stack remains. If you are looking for the old `quickshell/ii`
> tree or the `hypr/custom/*.lua` layout it used, it is in the history, not here.

---

## What is in this repo

    config/               User configs (~/.config/)
      caelestia/          THE shell config -- see below. The heart of this repo.
      hypr/               Hyprland Lua entry point + variables
      voxtype/            Local dictation: engine, VAD, replacements, OSD
      fish/ kitty/        Shell and terminal
      nvim/ mpv/ btop/    Editor, player, monitor
      cava/ easyeffects/  Audio visualiser and speaker DSP
      alacritty/ herdr/ yt-x/ spicetify/
      starship.toml, thorium-flags.conf, mimeapps.list

    local/                ~/.local/ -- things that are actual work, not installed files
      bin/extract-here    Archive extractor wired to Thunar via mimeapps.list
      bin/voxtype-submap  Hyprland Lua-dispatch shim for voxtype's submaps
      share/voxtype/quickshell/
                          voxtype's OSD, retargeted at caelestia's theme

    system/               Root-owned files. Applied by install.sh with sudo.
      modprobe.d/         T2 audio load order, hid_apple, Touch Bar autodim
      tiny-dfr/           Touch Bar daemon config
      ananicy.d/          Process priority overrides
      udev/rules.d/       T2 audio wake rule
      systemd/system/     t2bce-audio.service
      scripts/            t2-pci-wake.sh, t2bce-audio-load.sh

    packages/
      pacman-explicit.txt   Explicitly installed pacman packages
      aur-foreign.txt       AUR / foreign packages
      aur-pending.txt       AUR packages considered but not installed, with reasons
      SYSTEM-NOTES.md       Hardware facts worth not re-deriving
      T2-TUNING.md          The long-form tuning log for this machine
      papirus-accent/       Icon-theme accent sync (sudoers rule + helper)

    DICTATION.md          Build brief and implementation log for voxtype

---

## caelestia

caelestia ships its config in `/etc/xdg/quickshell/caelestia/`, which is
**package-owned and overwritten on every update**. Nothing in this repo touches
it. All customisation goes through the two extension points caelestia provides:

    config/caelestia/hypr-user.lua    Loaded last by ~/.config/hypr/hyprland.lua.
                                      Monitor scale, hyprpm, plugin config.
    config/caelestia/hypr-vars.lua    Loaded first -- variable/keybind overrides
                                      that must land before caelestia's modules.
    config/caelestia/custom/*.lua     Scrolling layout, rules, input, animations,
                                      border colours, keybinds, notepad launcher.
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
`~/.config/caelestia/templates/` on each scheme change, unconditionally. Two
live here:

    sddm-theme.conf      SDDM login theme colours
    zen-userChrome.css   Zen browser chrome, symlinked into the Zen profile

Syntax is `{{ colourname.form }}` where form is `hex` / `hexalpha` / `rgb` /
`rgbalpha`, plus `{{ mode }}`.

### Notepad

`config/caelestia/custom/notepad/` is a **separate Quickshell config** (`qs -p`),
not a caelestia module -- caelestia has no drop-in mechanism for user QML. It
imports caelestia's private plugins (`Caelestia.Config`, `Caelestia.Blobs`) from
`/usr/lib/qt6/qml/Caelestia/`, which are not a public API and can break on a
shell update. `CAELESTIA-BLOBS.md` in that directory documents the SDF blob
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
- Level 1 ("dim") is PWM'd and visibly flickers. `hid-appletb-kbd` dims after
  `dim_timeout` then powers off `idle_timeout` later, so
  `modprobe.d/hid-appletb.conf` sets `autodim=N` to pin it at max. The panel is a
  backlit LCD -- no burn-in cost.

### Suspend and hibernate

Suspend works **only through systemd** (`systemctl suspend`). `rtcwake -m mem`
bypasses `sleep.target` and hangs. Sleep hooks must live in
`/usr/lib/systemd/system-sleep/` -- systemd 261 silently ignores
`/etc/systemd/system-sleep/`.

Swap is a **20G swapfile with zswap**, not zram. This is a deliberate departure
from CachyOS's zram-only default: hibernate needs a real swap device, and a
swapfile under zram causes LRU inversion. Never add both.

### Keyboard modifier mapping

`modprobe.d/hid_apple.conf` sets `swap_opt_cmd=1` system-wide (physical Command =
SUPER). Hyprland counters with `kb_options = "altwin:swap_alt_win"` so the
logical mapping is right inside Wayland.

---

## Dictation

`voxtype` with **Parakeet TDT 0.6B v3 int8**, entirely local, CPU-only. int8
because this CPU has `avx512_vnni` -- quantised inference is the hardware fast
path here, not a compromise. Full build log in `DICTATION.md`.

    Super + Ctrl + X    toggle
    F9 (hold)           push-to-talk
    F12                 cancel / escape a stuck submap

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
