# Local Voice-to-Text Dictation — Build Brief

Port Omarchy's `Super + Ctrl + X` dictation feature to **CachyOS + Hyprland + Quickshell**.

Start from Phase 1. §11 records what was measured on this machine.

---

## 1. Context — what Omarchy actually does

Omarchy does **not** implement dictation itself. It is a thin wrapper around
[voxtype](https://github.com/peteonrails/voxtype) (Rust, whisper.cpp, fully local, MIT).

Omarchy contributes exactly four things on top of the package:

1. A menu install script (`Install > AI > Dictation`)
2. Hyprland keybinds
3. A Waybar module (red mic in the top bar center)
4. `[status] icon_theme = "omarchy"` in the voxtype config

Everything functional lives in voxtype. **We are reimplementing the thin layer, not the engine.**

Bindings in current Omarchy:
- `Super + Ctrl + X` — toggle dictation
- `F9` (hold) — push-to-talk

> Not verified directly: Omarchy's install script could not be read (GitHub blocked the
> directory listing). The above is from the v3.3.0 release notes, the Omarchy manual, and
> package versions reported in Omarchy issue threads. **If anything below misbehaves, check
> `~/.local/share/omarchy/install/` on a live Omarchy box before assuming voxtype is at fault.**

### Package split

| Package | Omarchy? | Notes |
|---|---|---|
| `voxtype-bin` | yes | Prebuilt AUR package. Confirmed as `voxtype-bin 0.7.3-1` in Omarchy issue #6029. Do **not** use the `voxtype` AUR package — it builds from source and drags in rustup/clang/cmake for no benefit. |
| `wtype` | dep | Wayland typing backend, preferred on Hyprland |
| `wl-clipboard` | dep | Clipboard fallback |
| `playerctl` | no | Not needed since voxtype 1.0.0 — MPRIS auto-pause talks D-Bus directly. Enabled via `[audio] pause_media = true`. |
| `vulkan-icd-loader` | no | GPU is opt-in via `voxtype setup gpu`. Likely already present on CachyOS via the Mesa/NVIDIA stack. |
| `tesseract`, `tesseract-data-eng` | yes | Only if we also want Omarchy's `Super + Ctrl + PrtScr` OCR-to-clipboard. Out of scope for v1. |

---

## 2. Target architecture

```
Hyprland keybind ──> voxtype record toggle/start/stop  (signals the daemon)
                                │
              voxtype daemon (systemd --user)
                     ├─ audio capture (PipeWire)
                     ├─ whisper.cpp inference (CPU or Vulkan)
                     ├─ optional post-process pipe (local LLM)
                     └─ output: wtype -> dotool -> ydotool -> clipboard
                                │
                     state file + `voxtype status --follow --format json`
                                │
                     Quickshell: OSD overlay + bar module
```

---

## 3. Phase 1 — Core install

```bash
paru -S voxtype-bin wtype wl-clipboard
voxtype setup model                 # base.en (150MB) default; large-v3-turbo if GPU
sudo voxtype setup gpu --enable     # Vulkan — big speedup, skip if CPU-only
voxtype setup systemd               # user service, starts on login
```

**Acceptance:** `voxtype setup` reports all green; `systemctl --user status voxtype` is active.

---

## 4. Phase 2 — Hyprland bindings

In `~/.config/voxtype/config.toml`, disable the built-in evdev hotkey — Hyprland drives it:

```toml
[hotkey]
enabled = false
```

Binds:

```
# toggle (Omarchy parity)
bind = SUPER CTRL, X, exec, voxtype record toggle

# push-to-talk
bind  = , F9, exec, voxtype record start
bindr = , F9, exec, voxtype record stop
```

### CRITICAL — modifier interference

```bash
voxtype setup compositor hyprland
hyprctl reload
systemctl --user restart voxtype
```

This installs a modifier-blocking submap at `~/.config/hypr/conf.d/voxtype-submap.conf` plus
pre/post output hooks. **Do not skip it.** Without it, releasing `X` while still holding `Super`
means the transcription "hello" fires `Super+h`, `Super+e`, `Super+l`... i.e. random window
management instead of text. This is Omarchy issues #4159 and #4185.

Escape hatch: if voxtype crashes mid-type and the submap sticks, press **F12**.

Ensure the Hyprland config sources `conf.d/`. Fallback if submaps are unusable:

```toml
[output.post_process]
command = "sleep 0.3 && cat"
timeout_ms = 5000
```

**Acceptance:** toggle in a terminal, then in a browser input, then deliberately release `X`
before `Super` — no stray shortcuts fire.

---

## 5. Phase 3 — Quickshell integration

Omarchy uses Waybar here; we do not. voxtype ships a native Quickshell OSD, so most of this
is configuration rather than code.

### 5a. OSD overlay

```toml
[osd]
frontend = "quickshell"
```

The launcher is `voxtype-osd-quickshell`. It resolves `[osd]` config **once at startup** and
writes the palette to `$XDG_RUNTIME_DIR/voxtype/quickshell-style.json` — so restart the daemon
after editing style config or nothing changes.

Custom style package = a directory containing a `voxtype-osd.toml` manifest, optionally naming
a `qml_entry`. Search path is typically `~/.config/voxtype/osd/<name>/`. If custom QML fails to
load it falls back to the built-in card and logs a warning; debug with:

```bash
voxtype-osd-quickshell --no-daemonize
```

### 5b. Bar module (our code)

Run `voxtype status --follow --format json --extended` as a long-lived `Process` and parse
stdout line-by-line with `SplitParser`. Payload shape:

```json
{ "text": "🎙️", "class": "idle", "tooltip": "...", "model": "base.en",
  "device": "default", "backend": "CPU (AVX-512)" }
```

Render a mic pill: `class` drives the color state, left-click runs `voxtype record toggle`,
right-click runs `voxtype configure`.

Requires `state_file = "auto"` in config.toml (the default).

> **Verify before writing QML:** the `Process` / `SplitParser` API has drifted across Quickshell
> releases. Check the installed version's docs rather than trusting a snippet. — done, see §11.

---

## 6. Phase 4 — Post-processing (optional, goes past Omarchy)

voxtype pipes the transcription through any stdin→stdout command, falling back to raw text on
timeout or error:

```toml
[output.post_process]
command = "ollama run llama3.2:1b 'Clean up this dictation. Fix grammar, remove filler words:'"
timeout_ms = 30000
```

Also worth setting:

```toml
[text]
spoken_punctuation = true          # "open paren" -> (   — useful when dictating code
replacements = { "vox type" = "voxtype", "trata tech" = "TrataTech", "polygon" = "Polygon" }
```

Domain vocabulary in `replacements` is the single highest-leverage accuracy fix — cheaper and
more reliable than jumping to a bigger model.

---

## 7. Reference config.toml

```toml
state_file = "auto"

[hotkey]
enabled = false          # Hyprland drives it

[audio]
device = "default"
sample_rate = 16000
max_duration_secs = 600

[audio.feedback]
enabled = true
theme = "default"
volume = 0.7

[whisper]
model = "base.en"        # tiny/base/small/medium/large-v3/large-v3-turbo
language = "en"
on_demand_loading = true # frees GPU/RAM when idle
# context_window_optimization = false   # leave off: causes phrase repetition on large-v3

[output]
mode = "type"            # "type" | "clipboard" | "paste"
fallback_to_clipboard = true
type_delay_ms = 1        # raise to 10-50 if characters drop

[output.notification]
on_recording_start = false
on_recording_stop = false
on_transcription = true

[osd]
frontend = "quickshell"

[vad]
enabled = true
threshold = 0.3          # lower = more sensitive; 0.5 default rejects quiet mics
```

---

## 8. Known pitfalls

| Symptom | Cause / fix |
|---|---|
| Typed text triggers WM shortcuts | Modifier interference — run `voxtype setup compositor hyprland` |
| "Cannot open input device" | Only affects built-in evdev hotkey; we disabled it, so ignore. Otherwise `usermod -aG input $USER` |
| Nothing typed | Check `which wtype dotool ydotool`; wtype needs `zwp_virtual_keyboard_v1` (Hyprland has it) |
| Characters dropped | `type_delay_ms = 10` |
| "word word word" repetition | Disable `context_window_optimization` (large-v3 / turbo) |
| `[BLANK_AUDIO]` / hallucinations on silence | Enable VAD, lower `threshold` |
| Slow on a hybrid-GPU laptop | whisper.cpp picks the iGPU at Vulkan index 0 — set `VOXTYPE_VULKAN_DEVICE=nvidia` or `[whisper] gpu_device = 1` |
| Style edits not applying | Restart the daemon; OSD style is resolved once at startup |
| Audio doesn't resume after dictating | Fixed in voxtype 1.0.0 — the D-Bus MPRIS path replaced the playerctl shell-out that caused Omarchy #6029 |

Debugging:

```bash
journalctl --user -u voxtype -n 50
voxtype -vv 2>&1 | tee debug.log
RUST_LOG=voxtype::output=debug voxtype
```

---

## 9. Open questions to resolve first

1. **Which machine?** If this is the Apple T2 box, validate mic capture before anything else:
   `pactl list sources short` then `arecord -d 3 -f S16_LE -r 16000 test.wav && aplay test.wav`.
   T2 audio is the single most likely thing to sink this.
2. **Quickshell version** — pin it, then check the `Process`/`SplitParser` API against that version.
3. **GPU path** — Vulkan available? Determines whether `base.en` or `large-v3-turbo` is the default.
4. **Scope** — is the deliverable a dotfiles patch, or a reusable installer script others can run
   on CachyOS? That changes how much of Omarchy's menu layer is worth rebuilding.

---

## 10. Sources

- voxtype: https://github.com/peteonrails/voxtype
- voxtype troubleshooting: https://github.com/peteonrails/voxtype/blob/dev/docs/TROUBLESHOOTING.md
- Omarchy manual (dictation): https://omarchy.org/manual/text-extraction-dictation/
- Omarchy v3.3.0 release notes: https://github.com/basecamp/omarchy/releases/tag/v3.3.0
- Modifier-key issues: basecamp/omarchy #4159, #4185

---

## 11. Measured on this machine (MacBookPro16,2, 2026-08-19)

Answers to §9, from the box itself rather than assumption.

### Machine — yes, the T2 box

```
card    alsa_card.pci-0000_e6_00.3   Active Profile: Default    (AppleT2x4)
source  alsa_input.pci-0000_e6_00.3.BuiltinMic   s24-32le 3ch 48000Hz   (default)
        alsa_input.pci-0000_e6_00.3.HeadsetMic   s32le 1ch 48000Hz
mute    no        volume 100% / 0.00 dB on all 3 channels
```

The card is on the **Default** profile, which is the one that matters here — `pro-audio`
runs no UCM and the T2 stays silent. See the T2 audio notes.

`[audio] device = "default"` in §7 resolves to `BuiltinMic`, so no override is needed —
**but** it is a 3-channel array at 48 kHz being downmixed to voxtype's 16 kHz mono.

**One of the three array channels is digitally dead.** 30 s raw capture at native
48 kHz / 3ch:

```
ch0  peak 390  loudest_100ms_rms 265  (-41.8 dBFS)
ch1  peak 663  loudest_100ms_rms 492  (-36.5 dBFS)
ch2  peak   0  loudest_100ms_rms   0  (-90.3 dBFS)   ← exactly zero, all 30 s
```

That matters for level: **the 3ch→mono downmix averages in a silent channel**, which
costs ~3.5 dB before anything else, and the earlier mono capture confirmed it (−45 dBFS
mono vs −36.5 dBFS on ch1 alone). If the speech margin turns out marginal, the fix is a
PipeWire remap-source taking ch1 only, pointed at by `[audio] device` — not more gain.

**The mic is quiet, and its noise floor is not acoustic.** Speech peaks at **−30.6 dBFS**
on ch1, about 10 dB below where a laptop mic should sit (−20 to −10). The floor underneath
it is ~−42 dBFS on ch1.

The floor is the odd part. Across a 30 s capture, ch1's 5th-percentile and 95th-percentile
100 ms windows were **−42.3 and −41.8 dBFS — a 0.5 dB spread**:

```
raw3.wav   ch1   floor -42.3   loud -41.8   SNR  0.5 dB
speech.wav ch0   floor -48.2   loud -45.7   SNR  2.5 dB
mictest.wav ch0  floor -48.2   loud -43.6   SNR  4.6 dB
```

Real room noise is never that flat. A constant-amplitude floor points at **electrical or
fixed-pattern noise from the T2 capture path**, not the room. Net usable margin is
therefore roughly 11 dB peak-to-floor, which is thin for whisper but not hopeless — the
model normalises level, so SNR is what decides accuracy, and steady broadband noise is
the kind it tolerates best.

Consequences for §7:

- Start `[vad] threshold` at **0.15–0.2**, not 0.3. At this level the 0.5 default would
  reject nearly every utterance.
- If accuracy is poor, the lever is **EasyEffects, which is already installed and running
  with an input pipeline** (`easyeffects_source` is live). Add gain + RNNoise there and set
  `[audio] device = "easyeffects_source"`. No new packages, and it fixes level and floor
  together — do this before reaching for a bigger model.
- The ch1-only remap above stacks with it, worth ~3.5 dB, but only if needed.

### Quickshell — 0.3.0, API confirmed

```
quickshell-git 0.3.0.r20.g28771c7-1
```

Checked against `/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes`, not a blog snippet:

- `Process.command` is `QString` with `isList: true` → **a list**, `["voxtype", "status", …]`,
  not a shell string.
- `Process.stdout` / `Process.stderr` are of type `DataStreamParser`.
- `SplitParser` has one property, `splitMarker` (QString), and inherits `DataStreamParser`.
- `DataStreamParser` emits `read(string data)` — that is the signal handler to write,
  `onRead:`, one call per line.
- `StdioCollector` also exists, for whole-output-at-once cases.

So §5b's shape holds on this version:

```qml
Process {
    command: ["voxtype", "status", "--follow", "--format", "json", "--extended"]
    running: true
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => root.state = JSON.parse(data)
    }
}
```

### GPU — Vulkan present, but **do not enable it here**

```
vulkan-icd-loader 1.4.357.0-1.1   vulkan-intel 3:26.1.6-1
deviceName  Intel(R) Iris(R) Plus Graphics (ICL GT2)   apiVersion 1.4.354   Mesa
```

Single GPU, so the hybrid-laptop pitfall in §8 does not apply and no
`VOXTYPE_VULKAN_DEVICE` is needed.

§3 calls `voxtype setup gpu --enable` a "big speedup" — that claim is written for discrete
GPUs. This is an **Ice Lake iGPU sharing the CPU's power and memory budget**, against an
i5-1038NG7 that has **AVX-512**, which is whisper.cpp's best CPU path. For `base.en` the
CPU is very likely to win, and it will not compete with the compositor for the iGPU.

**Start CPU-only with `base.en`.** Benchmark before enabling Vulkan, and only consider
`large-v3-turbo` if the GPU path measurably wins.

### Missing packages

```
wtype      MISSING     ← required, the preferred Hyprland typing backend
playerctl  MISSING     ← required for MPRIS ducking
dotool     MISSING     (optional fallback)
ydotool    /usr/bin/ydotool
wl-copy    /usr/bin/wl-clipboard
voxtype    not installed
```

### Scope — still unanswered

§9.4 is a decision, not a measurement. Nothing has been installed pending it.

---

## 12. Implementation notes — what actually differed from the brief

Built 2026-08-19. Everything below was verified on the machine, not assumed.

### Parakeet needed no rebuild

§9's model list said "rebuild with `--features parakeet`". That is wrong for this
package. `voxtype-bin` ships **every** variant under `/usr/lib/voxtype/` and symlinks
`/usr/bin/voxtype` to the plain whisper build at install time:

```
/usr/bin/voxtype -> /usr/lib/voxtype/voxtype-avx512        (before)
/usr/bin/voxtype -> /usr/lib/voxtype/voxtype-onnx-avx512   (after)
```

`sudo voxtype setup onnx --enable` flips it. Root is correct here despite the
warning the command prints — it is a system-wide symlink. The warning targets
`setup model` / `setup systemd`, which write into `$HOME`.

Model chosen: **`parakeet-tdt-0.6b-v3-int8`** (640 MB on disk). int8 because this CPU
has `avx512_vnni`, the instruction set that exists to accelerate int8 inference —
so the quantized model is the fast path, not a compromise. Loads in ~2.2–2.6 s.

### The brief's package list was half wrong

`wl-clipboard`, `ydotool`, `vulkan-icd-loader` and `tesseract` were already installed.
Only `wtype` and `playerctl` were missing, and neither is a dependency of
`voxtype-bin` (`Depends: alsa-lib curl gcc-libs glibc`) — they are optdepends and must
be named explicitly. Also: this box has **`yay`, not `paru`**.

### The OSD default frontend is broken here

The daemon respawn-looped on `OSD child exited: status=exit status: 127`. Cause: the
`voxtype-osd` dispatcher defaults to the **gtk4** frontend, which needs
`libgtk4-layer-shell.so.0` — not installed. Fixed with config, not a package:

```toml
[osd]
frontend = "quickshell"
```

The dispatcher searches `/usr/lib/voxtype/` directly, so the missing `/usr/bin`
symlink for `voxtype-osd-quickshell` is irrelevant. `voxtype setup quickshell`
installs the QML tree to `~/.local/share/voxtype/quickshell/`.

### Compositor integration had to be rewritten — do NOT run the installer

`voxtype setup compositor hyprland` is **wrong on this system in two independent
ways**, and running it would produce a silently dead integration:

1. It writes `~/.config/hypr/conf.d/voxtype-submap.conf`. **Nothing sources
   `conf.d/`** — caelestia's config is Lua (`~/.config/hypr/hyprland.lua`).
2. Its hooks call `hyprctl dispatch submap <name>`. On a Lua config `hyprctl
   dispatch` wraps its argument in `hl.dispatch(...)`, so that is a syntax error:

```
$ hyprctl dispatch submap reset
error: [string "return hl.dispatch(submap reset)"]:1: ')' expected near 'reset'
$ hyprctl dispatch 'hl.dsp.submap("reset")'
ok
```

Replacement, all user-owned files:

- **`~/.config/caelestia/custom/keybinds.lua`** — two `hl.define_submap(...)` blocks
  (`voxtype_recording`, `voxtype_suppress`) plus the binds. Confirmed registered via
  `hyprctl binds -j`: both submaps present, 11 suppress binds, and `release=True` on
  the second F9.
- **`~/.local/bin/voxtype-submap`** — 1-line wrapper emitting the Lua dispatch form,
  so `config.toml` holds a plain command with no nested quoting.
- **`config.toml [output]`** — the three hooks call that wrapper by absolute path,
  because the systemd user unit's PATH need not include `~/.local/bin`.

Bind collisions checked against `hyprctl binds -j` before writing: `SUPER+X`
(modmask 64) and `SUPER+ALT+F12` (72) are taken; `SUPER+CTRL+X` (68), bare `F9` and
bare `F12` were free. Bindings match Omarchy's: hold **F9**, toggle **Super+Ctrl+X**.

### VAD: the official docs' advice is wrong for this mic

`voxtype.io/docs/USER_MANUAL` recommends `backend = "auto"`. On this box that
resolves to **Energy VAD** — confirmed in the daemon log. Energy thresholding is
exactly what a ~11 dB-SNR mic defeats. Pinned explicitly instead:

```toml
[vad]
enabled = true
backend = "whisper"     # -> ggml-silero-vad.bin, the neural VAD
threshold = 0.3
```

Log confirms: `Using Whisper VAD backend with model ".../ggml-silero-vad.bin"`.

### Harmless noise in the log

`GPU device discovery failed: ... /sys/class/drm/card0/device/vendor` — `card0` is
the **Touch Bar** DRM device (`appletbdrm`), which has no PCI vendor node. ONNX
Runtime is running on CPU by design. Ignore it.

### Phase 4 is mostly unnecessary now

Parakeet TDT v3 emits its own punctuation and capitalisation, so the `[output.post_process]`
LLM cleanup pipe that §6 describes has no job left. `[text] replacements` is still
worth filling in — Parakeet's documented failure mode is swapping proper nouns for
phonetic lookalikes, which is exactly what that table fixes.
