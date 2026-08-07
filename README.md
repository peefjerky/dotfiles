# dotfiles

```
 ___  ___  ___  ___  ___  ___  ___  ___  ___
|   ||   ||   ||   ||   ||   ||   ||   ||   |
| p || e || e || f || s || - || m || b || p |
|___||___||___||___||___||___||___||___||___|

  MacBook Pro 2020 (T2) -- Arch Linux -- Hyprland
```

Personal system configuration for a MacBook Pro 7,1 (2020) running
Arch Linux with the linux-t2 kernel and the dots-hyprland / illogical-impulse
shell stack.

---

## Hardware

    Machine   : MacBook Pro 16,2 (2020)
    Chip      : Apple T2 Security Chip (BCE/VHCI audio + USB routing)
    Display   : eDP-1 @ 2560x1600, 226 PPI, scale 1.6
    Kernel    : linux-t2 (7.1.5+)
    GPU       : Intel Ice Lake GT2

---

## What is in this repo

    config/           User configs (~/.config/). Symlinked by install.sh.
      hypr/           Hyprland Lua config (dots-hyprland base + custom/ overrides)
      fish/           Fish shell config and functions
      kitty/          Kitty terminal
      wireplumber/    Custom WirePlumber rules (pro-audio profile for T2 BCE)
      pipewire/       PipeWire quantum / latency tuning
      easyeffects/    EasyEffects presets (mbp speaker DSP)
      nvim/           Neovim
      tmux/           Tmux
      mpv/            MPV player
      cava/           Cava audio visualizer
      btop/           Btop resource monitor
      alacritty/      Alacritty (secondary terminal)
      zathura/        Zathura PDF viewer
      rofi/           Rofi launcher
      spicetify/      Spicetify Spotify theming
      starship.toml   Starship prompt (end4 dots-hyprland style)
      *-flags.conf    Ozone/Wayland flags for Electron apps and Chromium-based browsers

    system/           /etc/ configs requiring root. Applied by install.sh with sudo.
      modprobe.d/     Kernel module blacklists (snd_soc_avs, apple_bce, HDA stack)
      udev/rules.d/   T2 audio wake rule (90-t2-audio-wake.rules)
      systemd/system/ t2bce-audio.service (delayed audio module load)
      polkit-1/       Power management rule (shutdown/reboot from Quickshell menu)
      ananicy.d/      Process priority overrides (browser, compositor, LowLatency_RT)
      scripts/        t2-pci-wake.sh, t2bce-audio-load.sh

    packages/
      pacman-explicit.txt   All explicitly installed pacman packages
      aur-foreign.txt       AUR / foreign packages (install via yay or paru)

---

## T2-specific notes

### Audio (t2bce_audio v0.01 -- linux-t2 7.1.5+)

The new t2bce driver stack replaces the old apple-bce. It has a known bug
where on some boots the T2 firmware does not expose the Speaker and Codec
Output subdevices before t2bce_audio probes. This leaves the ALSA card in a
broken state and causes a kernel oops when PipeWire opens the PCM device.

Workarounds applied here:

  1. t2bce_audio is blacklisted from autoloading (system/modprobe.d/t2-audio-late-load.conf)
  2. A systemd service (t2bce-audio.service) loads it after local-fs.target,
     giving the T2 firmware extra time to initialize.
  3. snd_soc_avs is blacklisted (system/modprobe.d/t2-audio-fix.conf) to stop
     the Intel AVS/HDA stack from racing with t2bce_audio for PCM registration.
  4. WirePlumber is configured with pro-audio profile + api.acp.auto-profile=false
     to bypass broken ACP profile probing entirely.

If audio is absent after boot, one manual reboot resolves it. This is a
driver-level bug -- track fixes at: https://github.com/t2linux/kernel

### Keyboard modifier mapping

/etc/modprobe.d/hid_apple.conf sets swap_opt_cmd=1 system-wide (physical
Command = SUPER, physical Option = ALT). The Hyprland config counters this
with kb_options = "altwin:swap_alt_win" so the logical mapping is correct
inside Wayland.

### Display scale

eDP-1 is configured at scale 1.6 in custom/general.lua. Valid scale steps
on this panel are 1.33, 1.5, and 1.6. Quickshell has QT_SCALE_FACTOR=1 to
avoid double-scaling.

### WiFi

apple-bcm-firmware covers the Broadcom chip. No kernel params needed on Arch
if that package is installed (non-iMac models only).

---

## Installation

### Requirements

- Arch Linux with linux-t2 kernel
- dots-hyprland installed (https://github.com/end-4/dots-hyprland)
- yay or paru for AUR packages
- GNU Stow (optional, for symlinking) or use install.sh directly

### Steps

    git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    bash install.sh

The script symlinks config/ entries into ~/.config/ and applies system/
files with sudo.

### Packages

    # Pacman packages
    sudo pacman -S --needed - < packages/pacman-explicit.txt

    # AUR packages (review first)
    cat packages/aur-foreign.txt | awk '{print $1}' | xargs yay -S --needed

---

## Layout notes

    hypr/hyprland/*.lua     Shipped by dots-hyprland. Overwritten on updates.
                            Do not edit these directly.
    hypr/custom/*.lua       User overrides. Persist across dots-hyprland updates.
                            All personal configuration lives here.
    hypr/CLAUDE.md          Full session notes, gotchas, and decisions log.
    hypr/LEGACY_CONFIG_ARCHIVE.md
                            Pre-Lua config archive (reference only, not live).

---

## Backup

See backup.sh in the repo root for rsync commands to an external drive.
Run it before any major system change or distro reinstall.

---

## License

Do whatever you want with this. No warranty.
