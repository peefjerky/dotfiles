# Casting this laptop to a TV or projector

Moonlight (on the receiver) + Sunshine (here). ~30–60ms latency. Miracast and
AirPlay are both dead ends on this hardware — see the bottom before retrying either.

---

## Running it

```fish
projector start     # start or resume the Desktop stream
projector stop      # end the session and close Moonlight
projector status    # what Sunshine thinks is going on
```

That is the whole interface. It starts Sunshine, finds the projector over mDNS,
connects ADB, drives Moonlight's UI, and disconnects again. `stop` handles both
cases — quitting from the app menu when idle, and killing the client then
closing Moonlight when mid-stream — then stops Sunshine.

**Sunshine is deliberately not enabled at login.** It only runs while you are
casting, so nothing is listening on the network the rest of the time. `projector`
brings it up and takes it down; if a start fails before a session exists, it
stops the host again rather than leaving it up.

Consequence: **starting from the projector's remote no longer works on its own.**
Moonlight won't find `peefshackbook` unless Sunshine is already running. Either
use `projector start` from here, or start the host first:

```fish
systemctl --user start app-dev.lizardbyte.app.Sunshine.service
```

To go back to the old always-on behaviour:

```fish
systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service
```

Raw ADB, if you need it:

```fish
adb connect (avahi-browse -rtp _adb._tcp | grep -m1 '^=;.*IPv4' | cut -d';' -f8,9 | tr ';' ':')
adb shell am start -n com.limelight/.PcView
adb disconnect
```

Never look up the IP by hand — the projector advertises `_adb._tcp` over mDNS.
(`adb mdns services` would do this natively, but Arch builds android-tools
without mDNS support.) It only answers in AirPlay/network mode; in Miracast mode
it leaves the network entirely.

Host status:

```fish
systemctl --user status app-dev.lizardbyte.app.Sunshine.service
```

### Pairing a new client

Sunshine has to be running (`projector status` will say so). Moonlight shows a
4-digit PIN; enter it in the web UI at <https://localhost:47990>. Self-signed cert, so the browser will warn — it's
localhost, accept and continue.

No browser? `sunshine -0` reads the PIN from stdin instead (stop the service
first, restart it after).

### Firewall

Already done, but if you ever reset ufw:

```fish
sudo ufw allow in on wlan0 to any port 47984,47989,48010 proto tcp
sudo ufw allow in on wlan0 to any port 47998:48010 proto udp
```

Scoped to `wlan0` rather than a subnet so it survives switching networks. On an
untrusted network these ports are reachable by anyone on that wifi — Sunshine
still requires PIN pairing before it streams, but tighten to
`from <subnet> to any port ...` if that matters.

### Resolution

Set on the **Moonlight** side, not in Sunshine — nothing on the laptop reveals
it, and Moonlight defaults to 720p. Settings live behind the gear on Moonlight's
PC list; from here that's:

```fish
projector stop
adb connect (avahi-browse -rtp _adb._tcp | grep -m1 '^=;.*IPv4' | cut -d';' -f8,9 | tr ';' ':')
adb shell am start -n com.limelight/.PcView
adb shell input keyevent KEYCODE_DPAD_CENTER   # default focus is the gear
# tap "Video resolution", pick 1080p, then BACK twice
adb disconnect
projector start
```

Confirm it took from the bitrate Sunshine negotiates — it scales with pixel count:

```
720p60   ->  8308000
1080p60  -> 16988000
```

```fish
journalctl --user -u app-dev.lizardbyte.app.Sunshine.service | grep 'Streaming bitrate'
```

Reading it any other way is awkward: `run-as` is denied on the release build,
and the box's `HI_VPLUGIN` spam rolls Moonlight's lines out of logcat within
minutes.

### Black bars

Laptop is 2560x1600 (16:10), projector 1920x1080 (16:9), so 1080p still letterboxes.
Moonlight's "Stretch video to full-screen" removes the bars by distorting; leave
it off unless you prefer that trade.

---

## The projector

```
EO9022-6a71
  :7000  AirPlay      AirTunes/220.68, reports AppleTV3,1
  :5000  AirTunes audio
  :7100  legacy AirPlay mirroring
  :5555  adb          Android 12, armeabi-v7a, HiSilicon Hi3751V350, TV build
```

It has an AirPlay mode (on the network) and a Miracast mode (Wi-Fi Direct, off
the network). It can't be in both.

---

## Things that don't work, and why

**Miracast — impossible on this laptop.** Apple's BCM4364 firmware rejects P2P
device creation:

```
brcmf_p2p_set_firmware: failed to update device address ret -52
brcmf_cfg80211_add_iface: add iface p2p-dev-wlan0 type 10 failed: err=-52
```

Apple's peer-to-peer stack is AWDL (AirDrop, Sidecar), not Wi-Fi Direct, so the
P2P iovars aren't implemented. `iw list` advertises P2P-GO/P2P-client because
that's the *driver's* capability table; the firmware never backs it. No
supplicant works around this — don't switch off iwd for it.

**castr / doubletake — can't drive this projector.** It answers `200 OK` with a
zero-length body to `/info`, `/pair-setup` (raw and TLV8) and `/pair-pin-start`
alike: it implements none of the AirPlay 2 pairing flows. There's no PIN to
find; its mDNS record says `pw=false`.

**AirPlay would work, but only badly.** The legacy `/play` endpoint needs no
pairing and will stream a fragmented MP4 over plain HTTP — but the receiver
treats it as a video file and buffers ~2s no matter what the sender does. That's
why this setup uses Moonlight instead.

**Sunshine crashes on startup without these.** In `~/.config/sunshine/sunshine.conf`:

```
hevc_mode = 1
av1_mode = 1
```

Ice Lake has no AV1 encode entrypoint, and probing HEVC segfaults Sunshine on
this VAAPI stack — SIGSEGV in the encoder-probe path in `main()`. H.264 costs
some bitrate versus HEVC but nothing in latency. Upstream bug.

---

## Troubleshooting

**Moonlight doesn't find the host.** Discovery is mDNS. Check the service is
active and avahi is running. From the projector,
`adb shell curl -s -o /dev/null -w '%{http_code}' http://<laptop>:47989/`
should print `200` — `000` means ufw.

**Stream connects then black.** Capture is `wlgrab` (wlr-screencopy) on `eDP-1`.
If you change monitors, check `capture` and the monitor list in the Sunshine log.

**A "Resume Session" entry appears, or the encoder keeps running after you
stopped.** Force-stopping Moonlight kills the client but leaves Sunshine holding
the session open. `projector stop` detects this and restarts the host to clear
it; by hand:

```fish
systemctl --user restart app-dev.lizardbyte.app.Sunshine.service
```

Pairing survives a restart — it lives in `sunshine_state.json`.

**You changed Wi-Fi networks.** Casting itself is fine — Moonlight re-finds
Sunshine over mDNS at the new address, and `projector` discovers the projector
the same way. Neither hardcodes an IP.

What can happen is Moonlight sits in `.Game` still pointed at the laptop's old
address, streaming nothing. `projector start` detects that (in `.Game` but no
traffic) and restarts the client so it re-resolves. `projector status` will show
`0 KB/s (idle)` while it's in that state.

**`projector` taps the wrong thing.** Buttons are found by on-screen text, but
app tiles are images with no text, so the first tile's position is the one
hardcoded value: `APP_TILE` in `local/bin/projector`, measured on the projector's
1920x1080 panel. Re-measure with `adb exec-out screencap -p > /tmp/s.png`.

**Moonlight's own activities can't be launched directly.** `AppView` and
`ShortcutTrampoline` aren't exported and this box's shell lacks
`START_ANY_ACTIVITY`, so `am start` gets a `SecurityException` for anything but
`PcView`. That's why `projector` drives the UI.
