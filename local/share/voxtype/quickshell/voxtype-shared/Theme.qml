pragma Singleton

// Voxtype Quickshell theme, rebound onto caelestia.
//
// Upstream shipped this as a table of hard-coded hex constants mirroring
// src/osd/visual.rs's fallback palette, with a comment promising a "Wave 2"
// loader for ~/.config/omarchy/current/theme/colors.toml. We don't run Omarchy,
// so instead every colour below is a live binding onto Colours, which watches
// ~/.local/state/caelestia/scheme.json. Change the wallpaper and this retheme
// follows with no restart -- the OSD is a separate process from caelestia's
// shell, but they read the same file.
//
// Sizing comes from Caelestia.Config's Tokens for the same reason: the OSD
// should pick up caelestia's rounding/spacing scale rather than swayosd's.
//
// NOTE: `voxtype setup quickshell` overwrites this whole directory. Re-apply
// after a voxtype update -- the originals are in /usr/share/voxtype/quickshell/.

import QtQuick

QtObject {
    id: theme

    /// Card background. Transparency-aware: follows caelestia's own
    /// transparency toggle through Colours.tPalette rather than a fixed alpha.
    property color bgColor: Colours.tPalette.m3surfaceContainer

    /// Theme accent -- matugen's primary, the same colour caelestia uses for
    /// its own visualiser bars (modules/dashboard/media/CoverVisualiser.qml
    /// binds strokeColor to Colours.palette.m3primary).
    property color accentColor: Colours.palette.m3primary

    /// Idle: visible but not capturing. Muted so it recedes.
    property color idleColor: Colours.palette.m3onSurfaceVariant

    /// Recording: capturing right now. The accent, so "live" reads as the
    /// wallpaper's own colour rather than voxtype's stock red.
    property color recordingColor: Colours.palette.m3primary

    /// Streaming: live partial-token output.
    property color streamingColor: Colours.palette.m3secondary

    /// Transcribing: model is chewing on the final buffer.
    property color transcribingColor: Colours.palette.m3tertiary

    property color textColor: Colours.palette.m3onSurface
    property color waveformColor: theme.accentColor
    property color waveformPeakColor: Colours.palette.m3onSurface

    /// Peak-meter zones. Low/mid stay on the scheme so they retheme; only the
    /// clipping zone is pinned to error, because "you are clipping" should not
    /// be a colour that blends in.
    property color meterLowColor: Colours.palette.m3primary
    property color meterMidColor: Colours.palette.m3tertiary
    property color meterHighColor: Colours.palette.m3error

    // Literals, not Tokens.*: caelestia's Tokens are per-screen and a QML
    // singleton has no screen, which logs "Tokens.rounding accessed without a
    // screen set". These mirror caelestia's large step; anything that genuinely
    // needs live Tokens reads them in OsdSurface.qml, where a screen exists.
    property int cornerRadius: 16
    property int padding: 12
    property int marginPx: 12

    property int defaultWidthPx: 400
    property int defaultHeightPx: 48
    property real defaultOpacity: 0.95

    property real waveformWindowSecs: 3.0
    property real peakDecayDbPerSec: 6.0

    /// Visual gain on the envelope before drawing. Upstream's 10.0 assumes
    /// voice peaking at 0.1-0.3 of full-scale; this machine's mic measured
    /// 0.03 (-30.6 dBFS peak), so at 10.0 the visualiser is a flat line.
    property real waveformGain: 39.0

    property real meterFloorDbfs: -60.0
}
