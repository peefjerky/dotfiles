# T2 Intel MacBook on CachyOS — tuning research

Research notes for **MacBookPro16,2** (13", 2020, Intel i5-1038NG7 Ice Lake, Iris Plus
G7, T2). Compiled 2026-08-16 from the CachyOS wiki and forum, the t2linux wiki, and
community tuning guides — then checked against this actual machine.

Companion to [[SYSTEM-NOTES]], which records what is *configured* here. This file
records what the *community* recommends and whether it applies.

> **How to read this.** Every claim is tagged:
> - ✅ **Verified here** — I ran the command on this box, output quoted.
> - 📖 **Community** — sourced claim, not yet tested here.
> - ⚠️ **Applies later** — true upstream, not yet true of this kernel.
>
> The tags matter more than the advice. Most T2 guides online are written for
> `MacBookPro16,1` (the 16", i9 + AMD dGPU) and a lot of it is actively wrong for
> this machine, which is iGPU-only.

---

## TL;DR — what actually matters here

| Finding | Status |
|---|---|
| CPU is **not** thermally throttling | ✅ `throttle_count = 0` |
| Power limits are **not** capping anything | ✅ RAPL long-term = 100 W |
| `t2fanrd` is installed but **disabled** | ✅ fans run on SMC firmware default |
| ananicy ran the desktop **below** the browser | ✅ fixed, see [[SYSTEM-NOTES]] |
| `t2_ncm` stalled boot by 60 s | ✅ fixed — upstream has a cleaner fix, below |
| Kernel will migrate `apple-bce` → `t2bce` | ⚠️ **will break our suspend script** |
| CachyOS kernel bumps have dropped T2 modules before | 📖 keep LTS installed |
| No VP9 hardware encode on this GPU | ✅ silicon limit, not configuration |
| Caelestia's Papirus accent-matching **already exists** — don't rebuild it | ✅ §13.3 |
| It failed silently: `sudo -n` with no NOPASSWD rule, stderr to `/dev/null` | ✅ fixed |
| Pale matugen accents collapse to white folders (saturation floor) | ✅ fixed via shim |
| `HYPRCURSOR_THEME` unset → shake-to-find drew a different cursor | ✅ pinned in `env.lua` |
| A cursor theme has **six** homes; `~/.icons/default` is the one that bites | ✅ §13.1 |

---

## 1. The throttling myth

Every T2 guide leads with thermal throttling. On this machine, measured after 45
minutes of browsing and tooling:

```
/sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count      0
/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count   0
/sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_max_time_ms 0
```

✅ **Zero throttle events.** Package sat at 81 °C with `high = crit = 100 °C`, fans at
3751 / 4061 RPM against maxima of 6336 / 6864. There is headroom in both.

RAPL is not the limiter either:

```
constraint_0_power_limit_uw = 100000000   # long_term  = 100 W
constraint_1_power_limit_uw = 125000000   # short_term = 125 W
```

100 W sustained on a 15 W-class chip is effectively uncapped — the firmware is not
holding the CPU back.

> **Caveat.** 45 minutes of light-to-moderate load. Re-check these counters
> immediately after a session that actually felt bad — a game, a long Meet call —
> because the counters are cumulative per boot and this window may simply not have
> been hot enough to prove anything.

**Conclusion for this box:** when the machine feels like it is "throttling", the cause
so far has always been something else — scheduler priority inversion, memory pressure,
or an i915 GPU hang. Chase those first. See §6 and §9.

### BD PROCHOT — the one thermal thing worth knowing

📖 On Intel Macs the T2/SMC can assert **BD_PROCHOT**, forcing the CPU to clock down
from an *external* signal regardless of actual die temperature. It is the standard
explanation for Intel Macs that throttle while cool, and there is a dedicated tool for
disabling it ([turnoff-BD-PROCHOT](https://github.com/yyearth/turnoff-BD-PROCHOT)).

Not checked here — reading MSR `0x1FC` needs the `msr` module, which is not loaded:

```fish
sudo modprobe msr
sudo rdmsr 0x1fc          # bit 0 set = BD PROCHOT enabled  (pkg: msr-tools)
```

⚠️ Disabling it means the CPU ignores a hardware protection signal. Given the throttle
counters above read zero, **there is currently no evidence this machine needs it.**
Recorded for completeness, not recommended.

---

## 2. The `apple-bce` → `t2bce` migration ⚠️ **read before the next kernel update**

The t2linux wiki has rewritten its suspend guidance. Current text:

> Current T2 kernels use t2bce, which handles suspend and resume for the BCE, VHCI,
> and audio stack internally. **Do not unload the t2bce modules before suspend.**
> Force-unloading them tears down active BridgeOS queues and can leave internal
> devices unavailable after resume. **When migrating from apple-bce, remove any old
> suspend service or elogind hook that unloads it** before testing suspend with t2bce.
>
> — [t2linux postinstall guide](https://wiki.t2linux.org/guides/postinstall/)

✅ This machine is **still on the old stack** — no action needed *yet*:

```
/lib/modules/7.1.8-1-cachyos/kernel/drivers/staging/apple-bce/apple-bce.ko.zst
lsmod: apple_bce 151552 1
find /lib/modules/$(uname -r) -iname '*t2bce*'   →   (nothing)
```

⚠️ **But `/usr/local/bin/t2-suspend.sh` unloads `apple_bce` on every sleep.** The
moment a CachyOS kernel ships `t2bce` instead, that script goes from load-bearing to
actively harmful. Check on every kernel bump:

```fish
find /lib/modules/(uname -r) -iname '*t2bce*' | head -1
```

Non-empty output ⇒ **disable `t2-suspend.service` / `t2-resume.service` before
rebooting into that kernel.** The same applies to the `brcmfmac` hibernate hook and to
`t2-touchbar-restore.service`, both of which exist to paper over the old stack's
suspend gaps.

The new stack also renames the early-boot modules — `t2bce_dma`, `t2bce_core`,
`t2bce_vhci` (the last is what makes the keyboard work at a LUKS prompt).

---

## 3. Kernel — the recurring T2 breakage pattern

📖 CachyOS kernel `7.1.2-2` shipped **without the `apple_bce` module at all**, leaving
T2 users with an unbootable kernel or a dead keyboard and trackpad:

```
==> ERROR: module not found: 'apple_bce'
ERROR: mkinitcpio failed for kernel 7.1.2-2-cachyos, skipping.
```

Two independent 2020 T2 MacBook Pro users plus a MacBook Air user hit it; one recovered
via btrfs snapshot, the rest fell back to `6.18 LTS`. Fixed in `7.1.3-1`.
— [CachyOS forum #32310](https://discuss.cachyos.org/t/missing-apple-bce-module-on-linux-cachyos-7-1-2-2/32310)

**The lesson is not "7.1.2 was bad".** It is that the T2 patches are out-of-tree
staging drivers carried on top of the CachyOS kernel, and they can silently fall off
during a rebase. This will happen again.

Mitigations, in order of laziness:

1. **Keep `linux-cachyos-lts` installed and in the boot menu.** It is the single
   highest-value insurance on this machine. Every user in that thread who had it
   recovered in one reboot.
2. Snapshots — already covered by btrfs + Limine here.
3. After any kernel update, before rebooting, confirm the module survived:
   ```fish
   ls /lib/modules/(uname -r)/kernel/drivers/staging/apple-bce/
   ```
   Watch for `ERROR: module not found` in the pacman output — it scrolls past easily.

Related: a `0006-t2.patch` regression routed a **non-T2** `MacBookAir6,2` down the
`applesmc` path and broke its keyboard backlight, which shows the T2 patches are not
perfectly fenced off from non-T2 Apple hardware.
— [CachyOS kernel-patches issue](https://github.com/CachyOS/kernel-patches)

---

## 4. Boot and login

✅ **Fixed here 2026-08-15.** Userspace boot went `1 min 5.7 s → 6.9 s`, and the stall
between the SDDM password and Hyprland appearing went from ~49 s to nothing.

Cause: the T2 chip exposes an internal USB-NCM ethernet interface (`t2_ncm`, driver
`cdc_ncm`). It reports carrier-up but has no DHCP server behind it, so NetworkManager
parked it in `connecting (getting IP configuration)` forever. `nm-online -s` waits for
*every* device to settle → the full 60 s timeout → `network-online.target` late →
`graphical.target` late → **uwsm blocks on `graphical.target` before starting
Hyprland**:

```
[19.4s] Authentication for user "peefjerky" successful
[20.2s] uwsm: graphical.target is queued for start, waiting for 60s...
[69.3s] Selected compositor ID: hyprland.desktop
```

Applied fix — disable autoconnect on the phantom profile:

```fish
sudo nmcli connection modify "Wired connection 1" connection.autoconnect no
```

Result: `NetworkManager-wait-online` **60026 ms → 47 ms**.

📖 **Upstream has a more robust fix** and it is worth migrating to. The t2linux wiki
stops NM from ever *creating* a default profile for the interface, rather than
disabling the one it made — so it survives profile regeneration, which ours would not:

```fish
printf '[main]\nno-auto-default=t2_ncm\n' | sudo tee /etc/NetworkManager/conf.d/99-network-t2-ncm.conf
```

The wiki also pins the interface name by MAC, which matters if it ever enumerates
differently:

```
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="ac:de:48:00:11:22", NAME="t2_ncm"
```

The wiki frames this as a fix for "recurrent NetworkManager notifications" — it does
not mention the boot stall, which appears to be undocumented.

---

## 5. Fan and thermal

✅ **`t2fanrd` is installed but `disabled` and `inactive` on this machine.** Fans still
spin (3751 / 4061 RPM measured), so the SMC firmware default curve is in control.

📖 The t2linux fan guide notes this is expected — "In some Macs, the fan has been found
to work out of the box. In such cases, the driver is not required unless you want to
force a certain speed or do some other configuration."
— [t2linux fan guide](https://wiki.t2linux.org/guides/fan/)

So this is **not broken**. But the daemon is the only way to get a curve that ramps
earlier than Apple's, which is the usual complaint. Config already present at
`/etc/t2fand.conf`:

```ini
[Fan1]
low_temp=55        # start ramping
high_temp=75       # full speed
speed_curve=linear
always_full_speed=false
```

To use it: `sudo systemctl enable --now t2fanrd`, then lower `low_temp` toward 45–50
for earlier, quieter-for-longer ramping.

⚠️ **Check the interaction with the suspend framework first.** `t2-suspend.sh` already
stops `t2fanrd` before sleep and `t2-resume.sh` restarts it — that pairing was written
assuming the service is enabled. Enabling it changes suspend behaviour, so test a
suspend cycle right after.

📖 Community consensus is that fan control is a **required** early step on older
(pre-T2) Macs — `mbpfan` from the AUR — but T2 machines generally do not need it.
— [CachyOS forum #11125](https://discuss.cachyos.org/t/intel-macs-are-reaching-the-eol-cachyos-to-the-rescue/11125)

---

## 6. Scheduler and CPU power

### The ananicy inversion ✅ fixed here

CachyOS ships `ananicy-cpp` enabled by default with rules that, on a Wayland desktop,
get the priority order **backwards**:

| Process | Shipped rule | nice |
|---|---|---|
| `qs` (caelestia shell) | `{ "type": "Service" }` | **+10** |
| `zen`, `thorium`, `chromium`, `brave`, `chrome` | `{ "type": "Doc-View" }` | **−4** |

That is a 14-level gap in the browser's favour. Worse, **nice is inherited across
`fork`**, so every content process inherits `−4` — verified, all ten of Zen's
processes were at `−4` including `Web Content` and `Isolated Web Co`, none of which
have rules of their own.

Hyprland itself is fine (`SCHED_RR` prio 1), which is why the compositor kept
compositing while everything *else* stuttered — the bar, panels, notifications and
overlay input all live in `qs`.

Fixed via `/etc/ananicy.d/99-local.rules`; details in [[SYSTEM-NOTES]].

**Generalisable lesson:** ananicy's `Service` type is meant for daemons. Any Wayland
shell that happens to match a `Service` rule by process name — `qs`, `dms`, `swaync` —
inherits a desktop-hostile priority. Worth auditing by name, not by assumption:

```fish
ps -o ni= -p (pgrep -f 'qs -c caelestia')
```

### CPU governor ✅ current state

```
scaling_driver               intel_pstate
scaling_governor             powersave
energy_performance_preference  performance
intel_pstate/no_turbo        0        # turbo enabled
```

`powersave` + HWP is the normal intel_pstate arrangement and is not a performance
problem. But `energy_performance_preference = performance` biases hard toward clocks
at all times, including on battery. `balance_performance` is the usual laptop setting
and is the obvious first knob for battery life. Untested here.

### sched_ext 📖 not enabled

```
/sys/kernel/sched_ext/state   disabled
scx_loader                    present but inactive
```

📖 `scx_lavd` is the community pick for laptops, specifically for **core compaction**:
below ~50 % CPU usage it keeps work on fewer cores at higher clocks and lets the rest
sit in deep C-states, which is a real win on a 4-core part. `scx_loader` exposes
`Auto` / `Gaming` / `LowLatency` / `PowerSave` modes.
— [CachyOS sched-ext wiki](https://wiki.cachyos.org/configuration/sched-ext/),
[forum #11078](https://discuss.cachyos.org/t/which-sched-ext-scheduler-would-you-recommend/11078)

Untested here. Given that the measured problem was priority inversion rather than
scheduling policy, this is a "maybe later", not a fix for anything known.

### TLP 📖 explicitly not recommended here

The Fedora T2 tuning guide leans on TLP, but its own instructions require removing
`tuned`/`tuned-ppd` and masking `systemd-rfkill` first.
— [g-r-3-y/fedora-macbook-pro-2019-16](https://github.com/g-r-3-y/fedora-macbook-pro-2019-16)

On this machine `power-profiles-daemon` is active and `thermald` is active+enabled.
Adding TLP means removing PPD and fighting CachyOS's defaults. Not worth it unless
battery life becomes the headline complaint.

---

## 7. Audio

✅ `AppleT2x4` — the model-specific 4-speaker layout is exposed correctly:

```
0 [Audio]: AppleT2x4 - Apple T2 Audio
```

📖 The t2linux audio guide uses exactly this string as its readiness check: if
`/proc/asound/cards` shows bare `AppleT2` with no digit, the driver stack is too old.
Ours is current. `apple-t2-audio-config` is installed.
— [t2linux audio guide](https://wiki.t2linux.org/guides/audio-config/)

⚠️ **Do not apply the speaker DSP config from that wiki.** It is written for the
MacBook Pro **16"** 2019 with **six** speakers, and the wiki warns in bold that each
model needs its own settings and using the wrong one *could damage the speakers*. This
is a 4-speaker 13". There is no published DSP profile for `MacBookPro16,2`.

Also relevant and already known here: the T2 card must be on the **Default** profile,
not `pro-audio`, or the amp never comes up. See [[SYSTEM-NOTES]].

---

## 8. Suspend, hibernate, and the community's low bar

📖 The most-cited T2 sleep thread is for a 2020 Intel MacBook Air — same T2 era, same
Ice Lake generation. Its resolution is instructive:

- OP's machine "just dies" on sleep and needs a reboot on power.
- The accepted answer is the t2linux **"Suspend workaround"**, and users are explicit
  that it is a workaround: *"It takes a bit to wake up but it's honestly ok."*
- One user reports **~10 % battery loss overnight** on suspend and calls that
  acceptable.
- Another's "solution" is to **disable sleep on lid close entirely**.

— [CachyOS forum #29595](https://discuss.cachyos.org/t/sleep-on-2020-intel-macbook-air-macbookair9-1/29595)

**This box is well ahead of that baseline.** Working here: suspend, hibernate to a
zswap-backed swapfile, suspend-then-hibernate on lid and idle, wifi restored across
hibernate, and the Touch Bar restored automatically on resume. All of it is documented
in [[SYSTEM-NOTES]].

Worth stating plainly because it changes how to read T2 advice online: most of it is
written by people who gave up on hibernate. The upstream guide that fixed the Touch Bar
also sets `AllowHibernation=no` for exactly that reason — **do not copy that part.**

---

## 9. Graphics and video

### i915 GPU hangs — still open

Not a T2 issue, an Ice Lake i915 issue. Symptom under Proton:

```
i915: Resetting rcs0 for preemption time out
… context reset due to GPU hang
```

Tried and rejected:

| Attempt | Result |
|---|---|
| `preempt_timeout_ms` 640 → 5000 | ❌ no change — proves the batch is *wedged*, not slow |
| WineD3D instead of DXVK | ⚠️ avoided the hang, but RSS 3.6 GB → 10 GB and heavy thrash |

Untested combination: DXVK + `DXVK_FRAME_RATE=30` + lower in-game resolution.

📖 `i915.enable_guc=2` (HuC loading, media offload) appears in T2 boot-parameter
recommendations. Ice Lake is Gen11 — GuC *submission* is Gen12+, so only the HuC half
is relevant, and it touches the same engine that is already hanging. Worth trying only
*after* the hang is understood, not as a shotgun.
— [schmeeve.com](https://schmeeve.com/cachyos-macbook-pro-intel-t2/)

### VA-API — decode good, encode capped by silicon

✅ Measured with `vainfo` (iHD 26.2.4, VA-API 1.24):

| Codec | Decode | Encode |
|---|---|---|
| H.264 | ✅ | ✅ `EncSlice`, `EncSliceLP`, FEI |
| VP8 | ✅ | ✅ `EncSlice` |
| VP9 | ✅ profiles 0–3 | ❌ **no encode entrypoint** |
| HEVC | ✅ incl. Main10/422/444 | ✅ |
| AV1 | ❌ | ❌ |

Consequences for video calls:

- **Firefox and Zen have no WebRTC hardware encode at all**, on any GPU.
  [Bug 969395](https://bugzilla.mozilla.org/show_bug.cgi?id=969395) has been `NEW`
  since 2014; the Fedora wiki states it is unsupported "no matter which preference you
  set at about:config". It needs work in the upstream WebRTC project (dmabuf /
  `kNative` surfaces), not a Firefox pref.
- **Chromium-family browsers can do it**, behind `AcceleratedVideoEncoder`.
- **But VP9 encode does not exist on this GPU.** If Meet negotiates VP9 outbound, it is
  software encode regardless of browser or flag.

The lever that works everywhere: **Meet → Settings → Video → Send resolution → 360p.**
Receive resolution can stay high.

Verify what is actually happening mid-call:

```fish
sudo intel_gpu_top      # pkg: igt-gpu-tools — watch the Video engine
```

---

## 10. Kernel parameters — what the guides say vs. what is set

✅ Current `/proc/cmdline`:

```
quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=… systemd.zram=0
zswap.enabled=1 resume=UUID=… resume_offset=18439406
```

📖 Commonly recommended for T2 and **absent here**:

| Parameter | Claimed purpose | Assessment |
|---|---|---|
| `intel_iommu=on iommu=pt` | Required for T2 audio pass-through per the t2linux audio guide | Audio works here without it. The guide targets non-T2 ISOs; CachyOS's `chwd` handles T2 setup differently. **Don't add speculatively.** |
| `pm_async=off` | Serialises device suspend; T2 suspend reliability | Plausible for the resume flakiness seen here. Cheapest untested experiment on this list. |
| `mem_sleep_default=s2idle` | Force s2idle | Already the only mode T2 supports; redundant. |
| `pcie_ports=compat` | Thunderbolt/PCIe quirks | From a `16,1` dGPU guide. |
| `i915.enable_guc=2` | HuC media offload | See §9 — same engine that hangs. |

📖 A separate forum report fixed **Thunderbolt docks** on a 2019 13" MacBook Pro with
`intel_iommu=on iommu=pt pcie_ports=native` — after which USB, LAN and audio on a
powered dock finally enumerated. Relevant only if a dock is ever used; four different
Lenovo/Dell docks failed without it.
— [CachyOS forum #11125](https://discuss.cachyos.org/t/intel-macs-are-reaching-the-eol-cachyos-to-the-rescue/11125)

⚠️ Kernel params are edited in `/etc/default/limine` here, then `sudo limine-update`.
Not GRUB — nearly every guide linked in this file assumes GRUB.

---

## 11. What does not apply to this machine

Filtering, since most T2 content targets the 16":

| Advice | Why it does not apply |
|---|---|
| `apple-gmux force_igd=y`, `gpu-switch`, vga_switcheroo | No dGPU. `16,2` is Iris Plus G7 only. |
| AMD dGPU suspend-reset service | Same. |
| "Limine does not enable the iGPU" caveat | That is a dual-GPU boot-order issue; iGPU-only here. |
| `mbpfan` from AUR | Pre-T2 Macs. T2 uses `t2fanrd`. |
| Legacy-BIOS / MBR install tricks | 2011–2015 Macs. |
| `linux-t2` / `linux-xanmod-t2` from `arch-mact2` | For stock Arch. CachyOS carries T2 patches in its own kernels; mixing would conflict. |
| Extracting wifi firmware from macOS | Already done — `apple-bcm-firmware` installed. |

---

## 12. Open items

Ordered by expected value.

1. **Re-read throttle counters after a bad session.** The zero reading is from 45 min
   of light use and does not yet prove the negative under load. `§1`
2. **Watch for `t2bce` on every kernel update.** Highest-consequence item in this file
   — the migration silently inverts what our suspend script should do. `§2`
3. **Install `linux-cachyos-lts` as a boot fallback** if it is not already there. `§3`
4. **Migrate `t2_ncm` to the upstream `no-auto-default` fix**, which survives NM
   profile regeneration. `§4`
5. **Try `energy_performance_preference=balance_performance`** for battery. `§6`
6. **Try `pm_async=off`** if suspend flakiness recurs. `§10`
7. **Consider enabling `t2fanrd`** with `low_temp` ~48 — but re-test suspend after,
   because `t2-suspend.sh` already stops the service. `§5`
8. **Disco Elysium:** DXVK + `DXVK_FRAME_RATE=30` + 1280×800, drop Heroic's
   `verboseLogs` and the pointless `PROTON_ENABLE_NVAPI=1`. `§9`

---

## 13. Cursors and icon theming

Compiled 2026-08-17. Two independent bugs, both of which look like "the theme just
won't stick" and neither of which is a theme problem.

### 13.1 A cursor theme has six homes, not one

Setting `XCURSOR_THEME` is not enough, and neither is `gsettings`. Each of these is
read by a different consumer, and any one left stale silently wins somewhere:

| Location | Read by |
|---|---|
| `~/.config/hypr/variables.lua` → `cursorTheme` | feeds `env.lua` + `execs.lua` |
| `~/.config/hypr/hyprland/env.lua` | `XCURSOR_*` / `HYPRCURSOR_*` for spawned clients |
| dconf (`gsettings ... cursor-theme`) | GTK apps |
| `~/.config/gtk-3.0/settings.ini` | GTK reading the file directly |
| `~/.config/xsettingsd/xsettingsd.conf` | xsettingsd (not running here) |
| `~/.icons/default/index.theme` → `Inherits=` | libXcursor fallback |

✅ **The last one is the trap.** `execs.lua` only fixes up processes that exist *after*
Hyprland starts. Anything launched outside that environment — systemd user units,
SDDM-spawned processes — resolves the theme literally named `default`, so a stale
`Inherits=` keeps resurrecting an old theme long after every other location is correct.
The 2026-08-08 restore left `Inherits=Bibata-Modern-Ice` here and it took three passes
to find.

✅ **`hyprctl reload` does not apply cursor changes.** The cursor commands live in
`execs.lua` under `hl.on("hyprland.start", …)` — startup-only, same semantics as
`exec-once`. Reload re-parses config without refiring it. Apply live with
`hyprctl setcursor` + `gsettings` instead.

✅ **`hyprctl keyword` is dead on this config.** The Lua parser rejects it:
`keyword can't work with non-legacy parsers`. Use `hyprctl eval 'hl.env(...)'`.

### 13.2 `HYPRCURSOR_THEME` unset → shake-to-find drew a different cursor

✅ Symptom: the `dynamic-cursors` shake-to-find magnifier rendered Bibata while
everything else rendered the configured theme.

Hyprland has two cursor paths. `cursor:enable_hyprcursor = true` (default) makes it
prefer hyprcursor; with `HYPRCURSOR_THEME` **unset** it resolves to whatever hyprcursor
theme it finds on disk. Only one existed — the restore's `Bibata-Modern-Ice`, the only
theme on the box carrying a `hyprcursors/` directory. Normal rendering fell back to
XCursor correctly; magnification went through hyprcursor and got Bibata.

Fixed by pinning it in `env.lua`, which also means it cannot drift again if another
hyprcursor theme is ever installed:

```lua
hl.env("HYPRCURSOR_THEME", vars.hyprCursorTheme)
hl.env("HYPRCURSOR_SIZE", vars.cursorSize)
```

**Current setup — deliberately two packages of the same artwork**, so both paths look
identical:

| Path | Theme | Source |
|---|---|---|
| XCursor (GTK3, XWayland, Electron) | `BreezeX-RosePine-Linux` | `rose-pine/cursors` v1.1.0 release, unpacked to `~/.local/share/icons` |
| hyprcursor (Hyprland, magnifier) | `rose-pine-hyprcursor` | AUR, `/usr/share/icons` |

`rose-pine-hyprcursor` ships **no `cursors/` directory** — it is hyprcursor-only. Alone
it would leave every client-side app on the Adwaita fallback.

✅ **Cursor size should land on a baked-in rung.** XCursor bitmaps are picked by nearest
size and then scaled. At `scale 1.6`, size 40 → 64 px, and BreezeX bakes
`22 24 28 32 40 48 56 64 72 80 88 96`, so both hit exactly. Check any theme with:

```python
# count TOC entries of type 0xfffd0002; subtype is the size
struct.unpack_from('<III', data, 16 + i*12)
```

⚠️ **Do not try to remove the stock cursor packages.** `adwaita-cursors`,
`breeze-cursors` and `default-cursors` are pulled in by `gtk3`, `libxcursor` and
`plasma-workspace`. Only third-party ones are safely removable.

### 13.3 Caelestia's Papirus accent-matching is real, and silently broken

✅ Caelestia already ships wallpaper-following folder colours — `manifest.toml`'s `gtk`
component installs `papirus-icon-theme` + `papirus-folders`, and
`caelestia/utils/theme.py` recolours on every scheme change. **Do not build a
replacement**; one was written here and thrown away.

The reason it appears dead (`caelestia-cli/utils/theme.py:246`):

```python
subprocess.Popen(
    ["sudo", "-n", "papirus-folders", "-C", color, "-u"],
    stderr=subprocess.DEVNULL,   # ← failure discarded
    stdout=subprocess.DEVNULL,
)
```

`sudo -n` is non-interactive. With no NOPASSWD rule it exits immediately, and stderr
goes to `/dev/null`, so it fails **completely silently**. The feature assumes a sudoers
rule that nothing installs. Fixed with `/etc/sudoers.d/papirus-folders`.

✅ **Second bug, visible only once sudo works.** `sync_papirus_colors` derives the
colour from raw RGB saturation (`theme.py:227-239`), and matugen's dark-mode primaries
are deliberately pale, so they fall under the `saturation < 20` floor and collapse to
white/grey. Worked example — a clearly green accent:

```
#b5cea9 → r=181 g=206 b=169
brightness = 206
saturation = (206-169)*100 // 206 = 17     → < 20 → grayscale → brightness ≥ 170 → "white"
```

Since `theme.py` is off-limits, the fix is a shim at `/usr/local/bin/papirus-folders`,
ahead of `/usr/bin` in sudo's `secure_path`. It rewrites only the `-C` value using
Oklab **hue** matching (ignoring lightness, which is what sends pale accents to white),
then `execv`s the real binary. Any failure inside falls through unchanged, so the worst
case is caelestia's original behaviour.

**The sudoers rule must list both paths** — once the shim exists, `sudo -n
papirus-folders` resolves to `/usr/local/bin` and no longer matches a `/usr/bin`-only
rule.

Both files are unowned by pacman, so they are copied into this repo:

```
packages/papirus-accent/usr-local-bin-papirus-folders    → /usr/local/bin/papirus-folders   (0755 root)
packages/papirus-accent/etc-sudoers.d-papirus-folders    → /etc/sudoers.d/papirus-folders   (0440 root)
```

Install the shim **before** the sudoers file, and always `sudo visudo -cf <file>` first —
a malformed drop-in locks you out of sudo entirely.

⚠️ **Survives caelestia-shell updates; `caelestia-cli` is the fragile link.** `theme.py`
belongs to `caelestia-cli`, not `caelestia-shell`. All three custom pieces are unowned
by pacman, and `hypr-user.lua` is created with `maybe_create` (returns early if present),
so none get overwritten. But a `caelestia-cli` upgrade that changes how `theme.py`
invokes `papirus-folders` would bypass the shim **silently**, since its stderr is
discarded. `papirus-folders --shim-selftest` proves the shim is healthy but *not* that
caelestia still reaches it. After any `caelestia-cli` upgrade, change wallpaper and:

```fish
readlink /usr/share/icons/Papirus-Dark/64x64/places/folder.svg
```

### 13.4 Thunar image previews

✅ `tumbler` is the thumbnailer daemon Thunar delegates to over D-Bus. Without it you
get generic icons no matter how Thunar is configured — it was simply missing. The
codecs (`ffmpegthumbnailer`, `poppler-glib`, `libopenraw`, `libgsf`) were already
present; `webp-pixbuf-loader` was added.

```
/misc-image-preview-mode      THUNAR_IMAGE_PREVIEW_MODE_STANDALONE   # dedicated pane
/last-image-preview-visible   true
/misc-thumbnail-mode          THUNAR_THUMBNAIL_MODE_ALWAYS
```

Thunar watches `notify::misc-image-preview-mode`, so these apply live; existing windows
need **F5** to re-render files scanned before tumbler existed.

### 13.5 Measured cost, for reference

Recolouring Papirus mutates the theme (relinks thousands of symlinks, then
`gtk-update-icon-cache`); switching between prebuilt variants is a dconf write. If this
ever needs revisiting:

| Approach | Per change | Disk |
|---|---|---|
| Papirus + `papirus-folders` | 5.1 s CPU, 48.6 MB peak | 0 (in-place) |
| Prebuilt variants + `gsettings` | ~51 ms, 7.6 MB peak | 607 MB (Colloid, all accents) |

Papirus wins on granularity (25 colours vs 9) and disk; the prebuilt approach wins on
compute. Papirus is what caelestia supports natively, which settles it.

---

## Sources

**Official**
- [CachyOS wiki — T2 MacBook install](https://wiki.cachyos.org/installation/installation_t2macbook/)
- [CachyOS wiki — sched-ext](https://wiki.cachyos.org/configuration/sched-ext/)
- [CachyOS wiki — Chromium HW acceleration](https://wiki.cachyos.org/configuration/enabling_hardware_acceleration_in_google_chrome/)
- [t2linux wiki — postinstall](https://wiki.t2linux.org/guides/postinstall/) — the `t2bce` warning
- [t2linux wiki — audio](https://wiki.t2linux.org/guides/audio-config/)
- [t2linux wiki — fan](https://wiki.t2linux.org/guides/fan/)
- [t2linux wiki — Arch FAQ](https://wiki.t2linux.org/distributions/arch/faq/)

**CachyOS forum**
- [#32310 — Missing apple_bce module on 7.1.2-2](https://discuss.cachyos.org/t/missing-apple-bce-module-on-linux-cachyos-7-1-2-2/32310)
- [#29595 — Sleep on 2020 Intel MacBook Air](https://discuss.cachyos.org/t/sleep-on-2020-intel-macbook-air-macbookair9-1/29595)
- [#11125 — Intel Macs are reaching EOL](https://discuss.cachyos.org/t/intel-macs-are-reaching-the-eol-cachyos-to-the-rescue/11125)
- [#24190 — Clean install on MacBook Pro 11,5](https://discuss.cachyos.org/t/cachyos-clean-install-on-macbook-pro-11-5-mid-2015/24190)
- [#11078 — Which sched-ext scheduler](https://discuss.cachyos.org/t/which-sched-ext-scheduler-would-you-recommend/11078)

**Community guides**
- [schmeeve.com — CachyOS + MacBook Pro (Intel, T2)](https://schmeeve.com/cachyos-macbook-pro-intel-t2/) — `16,1`, dGPU-focused
- [g-r-3-y/fedora-macbook-pro-2019-16](https://github.com/g-r-3-y/fedora-macbook-pro-2019-16) — TLP-based tuning
- [sebastienrousseau/iceunit](https://github.com/sebastienrousseau/iceunit) — MacBookAir9,1 scripted setup
- [yyearth/turnoff-BD-PROCHOT](https://github.com/yyearth/turnoff-BD-PROCHOT)

**Upstream bugs**
- [Mozilla #969395 — HW VP8 encode for WebRTC](https://bugzilla.mozilla.org/show_bug.cgi?id=969395) — NEW since 2014
- [Mozilla #1646329 — VA-API decoder with WebRTC](https://bugzilla.mozilla.org/show_bug.cgi?id=1646329)
- [Fedora wiki — Firefox hardware acceleration](https://fedoraproject.org/wiki/Firefox_Hardware_acceleration)

---
---

# ACTION LIST

Compiled 2026-08-16. Ordered by value per unit of risk. Commands are **fish**.

## Safety net

`snapper` + `snap-pac` + `limine-snapper-sync` are all installed, and Limine's
`BOOT_ORDER` already includes `Snapshots`. Every `pacman` transaction is snapshotted
automatically, so anything installed via pacman is one boot-menu entry away from being
undone.

⚠️ **What snapshots do *not* cover:** the `root` snapper config is `/` only. Changes
under `/home` — which includes every `~/.config` file touched here — are **not**
snapshotted. Manual snapshot before a risky batch:

```fish
sudo snapper -c root create -d "before T2 tuning batch"
sudo snapper -c root list | tail -5
```

---

## Tier 1 — do now (safe, reversible, no reboot)

> **Status 2026-08-16:** items 1, 2b, 6 and 7 applied and verified. Item 2 rejected by
> choice. Items 3 and 4 declined — see notes on each.
>
> Verified state after the `pm_async=off` reboot:
>
> | Check | Result |
> |---|---|
> | `pm_async=off` in `/proc/cmdline` | active |
> | `NetworkManager-wait-online` | **115 ms** (was 60026 ms) |
> | `t2fanrd` | active, curve 40→65 |
> | Boot total | 22.4 s (userspace 6.8 s, was 1 min 5.7 s) |
> | `throttle_count` | still 0 |

### 1. Replace the `t2_ncm` fix with the upstream one — ✅ **DONE 2026-08-16**

`/etc/NetworkManager/conf.d/99-network-t2-ncm.conf` in place, `t2_ncm` reports
`disconnected` rather than perpetually `connecting`.

Ours disables autoconnect on the profile NM generated. Upstream stops NM from ever
generating it, which survives profile regeneration. Ours breaks silently if that
profile is ever recreated; this one does not. `§4`

```fish
printf '[main]\nno-auto-default=t2_ncm\n' | sudo tee /etc/NetworkManager/conf.d/99-network-t2-ncm.conf
sudo systemctl reload NetworkManager
```

Then confirm the boot win survived on the next reboot:

```fish
systemd-analyze blame | grep wait-online     # want < 1s, was 60026ms
```

Keep the `autoconnect no` setting as well — belt and braces, they do not conflict.

### 2. ~~Drop the power profile off `performance`~~ — ❌ **REJECTED 2026-08-16**

Owner's call: *"Noise doesn't bother me at all, I want the best performance."* Stay on
`performance`. The rest of this item is kept only as the battery trade-off, should
priorities change.

<details>
<summary>Original recommendation (battery-oriented)</summary>

#### Drop the power profile off `performance`

`powerprofilesctl get` returns **`performance`**, which is what pins
`energy_performance_preference=performance` — the CPU biases to clocks at all times,
including on battery. `power-profiles-daemon` owns this knob, so set it through PPD;
writing the sysfs file directly just gets overwritten. `§6`

```fish
powerprofilesctl set balanced
```

Reversible instantly with `powerprofilesctl set performance`. Given §1 showed zero
throttling and plenty of thermal headroom, `balanced` costs little and is the single
biggest battery lever available right now.

</details>

### 2b. Max-performance fan curve — ✅ **applied 2026-08-16**

Supersedes the `low_temp=48` setting from item 6. Full speed by 65 °C rather than 75:

```fish
sudo sed -i 's/^low_temp=.*/low_temp=40/; s/^high_temp=.*/high_temp=65/' /etc/t2fand.conf
sudo systemctl restart t2fanrd
```

At 60 °C this commands ~80% (≈5300 RPM) instead of ~26%.

**Why not `always_full_speed=true`,** which the config also supports: it would not make
the machine faster. At idle there is no heat to move, so maximum fan buys nothing but
wear; by the time heat exists this curve is already saturated. Reaching max at 65 °C is
functionally identical for performance, and 65 °C is far below anything Ice Lake
throttles at.

⚠️ Keep expectations calibrated: §1 measured `throttle_count = 0` and RAPL long-term at
100 W. **Nothing on this machine is currently thermally limited.** This curve is
insurance for sustained load, not a speed-up that will be felt at the desktop.

### 3. Install the measurement tools

Neither is a tweak; both are needed to make the rest of this list evidence-based
instead of guesswork.

```fish
sudo pacman -S igt-gpu-tools msr-tools
```

- `sudo intel_gpu_top` — during a Meet call, watch the **Video** engine. Busy ⇒ real
  hardware encode. Flat while cores pin ⇒ Meet chose VP9 and this GPU cannot encode it.
- `sudo modprobe msr; sudo rdmsr 0x1fc` — bit 0 tells you whether BD PROCHOT is armed.
  **Read only.** Do not disable it; §1 shows no evidence this machine needs it.

### 4. Fix the Google Meet CPU cost — ⏸ **deferred 2026-08-16: running Meet in Thorium instead**

Thorium now has `AcceleratedVideoEncoder` (see [[SYSTEM-NOTES]]), so this may be
sufficient. **But it is conditional, not guaranteed**, and the condition is invisible
without measuring:

| Meet negotiates | Outgoing stream in Thorium |
|---|---|
| VP8 or H.264 | ✅ hardware encode — problem solved |
| **VP9** | ❌ **software encode** — this GPU has no VP9 encode entrypoint at all `§9` |

So if calls still pin the cores, the browser is not at fault and 360p is still the fix.
The check needs `intel_gpu_top` (item 3, declined): Video engine busy ⇒ hardware
encode; flat while cores pin ⇒ VP9, and no browser or flag can change that.

Original: **Meet → Settings → Video → Send resolution → 360p.** Receive can stay high.
The only lever that works across every browser and codec. `§9`

### 5. Disco Elysium — the untested combination

In Heroic, for this title: remove `PROTON_USE_WINED3D=1` (back to DXVK), keep
`DXVK_FRAME_RATE=30` and `WINEDEBUG=-all`, drop the game to 1280×800, turn off Heroic's
`verboseLogs`, and delete `PROTON_ENABLE_NVAPI=1` (there is no NVIDIA GPU here). `§9`

If it still hangs, capture the moment it does:

```fish
sudo dmesg -w | grep -iE "i915|GPU HANG|reset"
```

---

## Tier 2 — do next, but test after (needs a reboot or a suspend cycle)

### 6. Enable `t2fanrd` with an earlier ramp — ✅ **DONE 2026-08-16, verified**

Enabled with `low_temp=48`. Suspend cycle tested: `t2fanrd` is `active` after resume
and the fans respond. Steady state measured over 24 s:

```
t= 3s  pkg=63C  cmd=2568  actual=2574
t=12s  pkg=55C  cmd=2568  actual=2626
t=24s  pkg=55C  cmd=2568  actual=2566
```

Tacho tracks the commanded value within ~1%, and the curve is exact: at 55 °C,
`1250 + (55-48)/(75-48) × (6336-1250) = 2569` vs `cmd=2568`.

**Net result: quieter at idle than Apple's firmware** — ~2570 RPM against the 3751 RPM
measured before enabling the daemon, at comparable temperature — *and* it ramps earlier
under load. Both directions improved.

⚠️ **Do not panic at the numbers right after a resume.** Immediately post-resume the
fans read 5073 → 5706 → 6204 RPM (~90% of max) while the daemon was commanding ~2568.
That is spin-down lag plus the resume load spike, and it settles within about a minute.
Only judge the curve from `fan1_output` (commanded) vs a settled `fan1_input`.

Useful paths — note `applesmc_t2` exposes **fan control but no temperature sensors**,
so the daemon reads `coretemp`:

```
/sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/
  fan1_manual   1 = daemon in control
  fan1_output   commanded RPM
  fan1_input    actual RPM
/sys/class/hwmon/hwmon4/temp1_input   coretemp package
```

<details>
<summary>Original instructions (kept for reference)</summary>

Installed, `disabled`, `inactive`. Fans currently follow Apple's SMC curve. `§5`

```fish
sudo sed -i 's/^low_temp=55/low_temp=48/' /etc/t2fand.conf
sudo systemctl enable --now t2fanrd
```

⚠️ **Then immediately test a suspend cycle.** `/usr/local/bin/t2-suspend.sh` stops
`t2fanrd` before sleep and `t2-resume.sh` restarts it — that pairing was written while
the service was disabled and has never actually run against an enabled one.

```fish
systemctl suspend
# ...resume, then:
systemctl is-active t2fanrd            # want: active
sensors | grep -i fan
```

If the fan is dead after resume, `sudo systemctl disable --now t2fanrd` and note it here.

</details>

Tuning from here: `low_temp` sets where the ramp starts, `high_temp` where it hits
maximum. Lower `high_temp` toward 68 for a steeper ramp under sustained load; raise
`low_temp` back toward 52 if idle noise becomes noticeable. Restart with
`sudo systemctl restart t2fanrd` — no reboot needed.

### 7. Try `pm_async=off`

Serialises device suspend. It is the standard T2 recommendation and the cheapest
untested experiment for the resume flakiness seen on this machine. `§10`

⚠️ Kernel params live in `/etc/default/limine` here, **not** GRUB — every guide linked
in this file assumes GRUB.

```fish
sudo cp /etc/default/limine /etc/default/limine.bak-(date +%Y%m%d)
sudo sed -i 's/quiet nowatchdog/quiet nowatchdog pm_async=off/' /etc/default/limine
sudo limine-update
```

Verify after reboot with `cat /proc/cmdline`. Revert by restoring the `.bak`, or boot a
snapshot.

Do **not** batch this with `intel_iommu=on iommu=pt` — audio already works here without
them, and adding four params at once makes a regression impossible to attribute.

---

## Tier 3 — waiting on upstream, nothing to install

### 8. `t2bce` — ✅ checked 2026-08-16, **NOT shipped. Wait.**

```
find /lib/modules/ -iname '*t2bce*'                    →  (empty)
/lib/modules/6.18.42-1-cachyos-lts/…/staging/apple-bce →  present
/lib/modules/7.1.8-1-cachyos/…/staging/apple-bce       →  present
pacman -Si linux-cachyos → 7.1.8-1   (= running, nothing newer in repos)
```

Both installed kernels still carry `apple-bce`, and 7.1.8-1 is the newest CachyOS
offers. **There is nothing to install and no action to take.** Keep the current suspend
scripts exactly as they are.

**The trigger to act.** Run this after every kernel update, before rebooting into it:

```fish
find /lib/modules/(uname -r) -iname '*t2bce*' | head -1
```

Non-empty output means the migration landed. At that point, and *before* trusting
suspend on that kernel: `§2`

```fish
sudo systemctl disable t2-suspend.service t2-resume.service
```

…and re-evaluate the `brcmfmac` hibernate hook and `t2-touchbar-restore.service`, both
of which exist only to patch the old stack's gaps. The new stack handles suspend for
BCE, VHCI and audio internally, and force-unloading its modules "can leave internal
devices unavailable after resume" — the opposite of what our scripts do today.

Nothing here needs a snapshot; it is a check, not a change.

### 9. Kernel-update ritual (the recurring T2 risk)

`linux-cachyos-lts` (6.18.42) is ✅ **already installed** — the single best insurance
against the `7.1.2-2` class of failure, where the T2 staging module silently fell out
of the build and left users with a dead keyboard. `§3`

After every kernel update, before rebooting:

```fish
ls /lib/modules/(uname -r)/kernel/drivers/staging/apple-bce/
```

Empty or missing ⇒ **do not reboot into it.** Boot LTS or a snapshot. Also watch the
pacman output for `ERROR: module not found: 'apple_bce'`, which scrolls past easily.

---

## Tier 4 — measure before changing anything

### 10. Re-read the throttle counters after a bad session

The zero reading in §1 came from 45 minutes of light use. It does not yet prove the
negative under real load. Run this **immediately after** a session that actually felt
bad — a long game, a long call — without rebooting in between, since the counters are
per-boot:

```fish
grep -H . /sys/devices/system/cpu/cpu0/thermal_throttle/*count
sensors | grep -i package
```

Still zero ⇒ thermal is definitively not the problem here, and the whole
throttling-and-fan-curve branch of T2 advice can be closed out for good.
Non-zero ⇒ reopen §1, and only then does BD PROCHOT become worth a real look.

### 11. Leave these alone for now

| Tempting | Why not yet |
|---|---|
| `scx_lavd` / sched_ext | The measured problem was ananicy priority inversion, now fixed. Changing scheduler policy on top would confound any measurement. Revisit only if stutter returns. `§6` |
| `i915.enable_guc=2` | Touches the exact engine that is already hanging under Proton. Understand the hang first. `§9` |
| TLP | Requires removing `power-profiles-daemon` and fighting CachyOS defaults. Try Tier 1 item 2 first — it may be all the battery win needed. `§6` |
| Disabling BD PROCHOT | Overrides a hardware protection signal to solve a problem that has not been shown to exist. `§1` |
| Speaker DSP config | Published config is for the **6-speaker 16"**. This is a 4-speaker 13" (`AppleT2x4`). The wiki warns it *could damage the speakers*. `§7` |
| `intel_iommu=on iommu=pt` | Audio already works without it. Only relevant if a Thunderbolt dock is ever used. `§10` |
