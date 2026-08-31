# System notes — CachyOS on MacBookPro16,2

## NEVER merge `/etc/pacman.conf.pacnew`

The `.pacnew` shipped by the `pacman` package is upstream **Arch's** default config.
It knows nothing about CachyOS. Applying it would:

- **delete the entire CachyOS repo section** (`[cachyos]`, `[cachyos-v3]`,
  `[cachyos-v4]`, `[cachyos-core-v4]`, `[cachyos-extra-v4]`) — the system would lose
  every CachyOS package source
- drop `ParallelDownloads = 10` back to `5`
- drop `Color`, `ILoveCandy`, `VerbosePkgLists`, `DisableDownloadTimeout`

Checked 2026-08-08: the only thing the `.pacnew` adds that the live file lacks is two
**commented-out** pacman 7 options, `#DisableSandboxFilesystem` and
`#DisableSandboxSyscalls`. Both are no-ops while commented, so there is nothing to
take from it. Delete the `.pacnew` or leave it; never apply it wholesale.

This will recur on every `pacman` package update. Re-check the diff each time rather
than assuming — but the CachyOS repo block must always survive.

## Suspend — works, but only through systemd

Fixed 2026-08-08 with `benstaker/T2Linux-Suspend-Fix`. T2 modules must be unloaded
before sleep and reloaded after, or the machine goes down and never resumes:

- `t2-suspend.service` → `sleep.target.wants` — stops tiny-dfr, unloads
  `hid_appletb_bl`, `hid_appletb_kbd`, `appletbdrm` and the sensor stack, stops
  `t2fanrd`/`upower`/`NetworkManager`. It **no longer touches the BCE module**: the
  `apple_bce` block was removed on 2026-08-22 when the kernel moved to `t2bce`, which
  does its own PM. See [[T2-TUNING]] §2.
- `t2-resume.service` → `suspend.target.wants` (+ hibernate variants) — reverses it.
- Scripts in `/usr/local/bin/t2-*.sh`, config in `/etc/t2-suspend-fix/hardware.conf`,
  log in `/var/log/t2-suspend-fix.log`.
- The Touch Bar returns on its own via udev re-trigger; the `bConfigurationValue`
  0→2 workaround other guides describe is **not** needed on this machine.
- `install-apple-bce` mode was NOT used. It overwrites the module `linux-cachyos`
  ships and rebuilds the initramfs — reserve it as an escalation. Moot since 7.2.0
  anyway: the in-tree driver is now `t2bce`, not `apple-bce`.

**THE GOTCHA:** anything that suspends by writing `/sys/power/state` directly
**bypasses systemd**, so `sleep.target` is never reached and these hooks never
fire — the machine hangs. `rtcwake -m mem` does exactly this, which made the fix
look broken when it was simply never invoked. To test with an auto-wake, arm the
alarm separately and suspend through systemd:

```
sudo rtcwake -m no -s 60     # arm the RTC alarm ONLY
systemctl suspend            # goes through sleep.target
```

Resume takes 10-15s (modules reload in sequence) and may need two power-button
presses. Verify a run with `tail /var/log/t2-suspend-fix.log` — it is written
before journald freezes, so it survives a hang where the journal shows nothing.

**Also:** never `systemctl restart systemd-logind` on a live session — it kills
active sessions and logs the user out. Use `systemctl kill -s HUP systemd-logind`
to reload its config instead.

## mDNS: avahi owns it, systemd-resolved does not

Both were answering on :5353 and both were publishing this hostname, which is the
classic cause of `.local` name-conflict renames. avahi cannot simply be removed —
`pipewire-pulse` and `libcups` depend on it (also `nss-mdns`, `ostree`, `tinysparql`,
`vlc-plugin-avahi`).

Fixed 2026-08-08 with two changes:

- `/etc/systemd/resolved.conf.d/10-no-mdns.conf` → `MulticastDNS=no`
- `/etc/nsswitch.conf` `hosts:` line gained `mdns_minimal [NOTFOUND=return]` before
  `resolve`, so `.local` still resolves — via avahi now instead of resolved.
  Backup at `/etc/nsswitch.conf.bak-2026-08-08`.

Verify with: `resolvectl status | grep mDNS` (want `-mDNS`) and `avahi-browse -at`.

## Mirrors

`mirror.krfoss.org` served a stale repo DB and was removed from CachyOS's shipped
mirrorlists; the local lists still had it until they were merged from `.pacnew` on
2026-08-08. Backups at `/etc/pacman.d/*.bak-2026-08-08`.

Unlike `pacman.conf`, the **mirrorlist** `.pacnew` files *are* safe to adopt wholesale —
they contain no local configuration, only CachyOS's curated server list.

## Power management

- `power-profiles-daemon` owns CPU frequency policy (CachyOS default). Do not install
  `auto-cpufreq`, `tlp` or `tuned` — all refuse to coexist with it.
- `cpupower.service` must stay **disabled**; enabled, it fights PPD over the governor.
- `thermald` is enabled and complementary — it does thermal throttling via RAPL, not
  frequency policy. Verified to fit: i5-1038NG7, `processor_thermal_device` +
  `intel_rapl_msr` + `intel_powerclamp` loaded.

## Hardware facts worth not re-deriving

- Camera is **USB behind the T2**, served by `uvcvideo` (`/dev/video0`, `/dev/video1`).
  `facetimehd` is for the PCIe Broadcom 1570 in 2013–2015 Macs and does nothing here.
- There **is** a real ambient light sensor: `/sys/bus/iio/devices/iio:device0` → `als`,
  with chromaticity and colour-temperature channels. `iio-sensor-proxy` (repo package,
  pulled in by `kwin`) already exposes it.
- Wifi: NetworkManager with `wifi.backend=iwd`. `wpa_supplicant` is installed but must
  stay inactive.
- Swap is a **20G swapfile with zswap** in front of it, not zram -- a swapfile under
  zram causes LRU inversion. Hibernate therefore works. See the caelestia suspend notes.

## Notepad overlay — depends on caelestia's private QML plugins

`~/.config/quickshell/caelestia/modules/notepad/` is a module **inside** caelestia's
shell. Quickshell resolves a config name against every XDG config dir in order and
`~/.config` wins over `/etc/xdg`, so a tree at `~/.config/quickshell/caelestia/`
shadows the packaged one and `qs -c caelestia` loads it instead. Every entry there is
a symlink back to the package except this module and three patched `modules/drawers/`
files. Nothing under `/etc/xdg` is ever touched.

It was standalone at first (`qs -p ~/.config/caelestia/custom/notepad`, its own layer
surface) and moved because a separate translucent surface sat above caelestia's border
shadow and transmitted a dark band along its bottom edge. Sharing caelestia's
`BlobGroup` removes the seam and gets real blob merging with the launcher and sidebar.

It imports two **private** caelestia plugins from `/usr/lib/qt6/qml/Caelestia/`:

- `Caelestia.Config` → `Tokens` (rounding/spacing/fonts/animation curves) and `Config`
- `Caelestia.Blobs` → `BlobGroup`/`BlobRect`, the SDF spring renderer behind the
  liquid panel look

Both export at version **254.0**. They are not a public API, so a `caelestia-shell`
update can break the notepad at runtime. After a `caelestia-shell` upgrade re-run
`~/.config/quickshell/caelestia/modules/notepad/install.sh`, which re-symlinks any new
upstream files and re-applies the three patches, refusing to touch anything if they no
longer apply. If the shell stops loading, `pkill -x qs; qs -c caelestia` in a terminal
shows the import or property error; the fallback is to replace `Card.qml`'s `BlobRect`
with a plain `StyledRect`, which costs only the deformation.

`Tokens` and `Config` are **per-screen attached** configs. Any Item under a window that
sets `contentItem.Tokens.screen` inherits it, but a plain QObject does not — `BlobGroup`
is a QObject, so `Card.qml` sets `Tokens.screen` on it explicitly. Without that, every
token lookup warns and silently falls back to defaults.
