// Voxtype on-screen display surface (Quickshell frontend), retargeted at
// caelestia.
//
// Changes from upstream's version:
//   - Anchored bottom-right inside caelestia's screen border, rather than
//     bottom-centre at a hard-coded 72px. The [osd] position config key does
//     NOT reach this frontend -- it only drives the gtk4/native ones, which is
//     why this is a QML edit and not a config line.
//   - Waveform replaced with a bar visualiser in caelestia's own idiom (see
//     modules/dashboard/media/CoverVisualiser.qml): rounded bars, m3primary,
//     animated. Caelestia's own visualiser is driven by Audio.cava, which
//     analyses audio *output*; the mic data here comes from voxtype's
//     AudioBridge instead, so this shares the look and not the source.
//   - Colours/sizing come from voxtype-shared/Theme.qml, which now binds to
//     caelestia's live scheme.
//
// NOTE: `voxtype setup quickshell` overwrites this file.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import "voxtype-shared" as VT

PanelWindow {
    id: panel

    property string daemonState: "idle"
    property var audio: null

    readonly property bool active: daemonState !== "idle" && daemonState !== ""
    readonly property bool listening: daemonState === "recording" || daemonState === "streaming"

    // Stays mapped until the exit animation finishes -- `visible: active` alone
    // would unmap the layer surface the instant recording stops and the fade-out
    // would never render. Caelestia's toasts solve the same problem with
    // modelData.lock()/unlock() (Toasts.qml:107, :118).
    visible: active || card.opacity > 0.01
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.namespace: "voxtype-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Caelestia's Tokens/Config are per-screen; bind them to this panel's screen
    // so the scale matches (notepad does the same, NotepadWindow.qml:90-91).
    contentItem.Tokens.screen: panel.screen.name
    contentItem.Config.screen: panel.screen.name

    mask: Region {
        intersection: Intersection.Subtract
        x: 0; y: 0
        width: panel.width
        height: panel.height
    }

    readonly property color stateColor:
        daemonState === "recording"    ? VT.Theme.recordingColor
      : daemonState === "streaming"    ? VT.Theme.streamingColor
      : daemonState === "transcribing" ? VT.Theme.transcribingColor
      :                                  VT.Theme.idleColor

    // ---------------------------------------------------------------------
    // Level history
    // ---------------------------------------------------------------------

    // Derived from the space the layout actually gives the visualiser, so the
    // bars fill the card exactly instead of clipping or leaving a gap. The Row
    // is left-anchored and doesn't drive barArea's width, so this can't loop.
    readonly property int barCount: barArea ? Math.max(8, Math.floor(barArea.width / 6)) : 40

    // Newest-last list of bar magnitudes, 0..1. Rebuilt on a timer rather than
    // per audio frame: the bridge emits at ~100 Hz and re-laying out 34 bars
    // that often is pure waste when the display is 60 Hz.
    property var levels: []

    property real pendingPeak: 0

    function _pushLevel(v) {
        const l = panel.levels.slice();
        l.push(Math.max(0, Math.min(1, v)));
        while (l.length > panel.barCount)
            l.shift();
        panel.levels = l;
    }

    function _resetMeters() {
        levels = [];
        pendingPeak = 0;
    }

    Connections {
        target: panel.audio
        enabled: panel.audio !== null

        // Keep the loudest peak seen since the last bar tick, so a short
        // transient still shows up instead of being missed between samples.
        function onFrameReceived(peak, rms, vad, tsMs) {
            if (peak > panel.pendingPeak)
                panel.pendingPeak = peak;
        }
        function onDisconnected() {
            panel._resetMeters();
        }
    }

    Timer {
        running: panel.active
        interval: 33          // ~30 Hz, one bar per tick
        repeat: true
        onTriggered: {
            if (panel.listening) {
                panel._pushLevel(panel.pendingPeak * VT.Theme.waveformGain);
                panel.pendingPeak = 0;
            } else {
                // Transcribing: no audio arrives, so show an indeterminate
                // travelling wave instead of a dead flat line.
                const t = Date.now() / 220;
                panel._pushLevel(0.35 + 0.3 * Math.sin(t));
            }
        }
    }

    onDaemonStateChanged: {
        if (!active)
            _resetMeters();
    }

    // ---------------------------------------------------------------------
    // Card -- geometry mirrors caelestia's toasts exactly
    // (modules/utilities/toasts/ToastItem.qml + Toasts.qml), so this lands in
    // the same corner at the same size as the "Config loaded" / caps-lock
    // popups. Same width expression, same height formula, same radius, same
    // inner margins, same icon chip. Only the colours differ: the border and
    // icon carry voxtype's state instead of the toast severity.
    // ---------------------------------------------------------------------

    Rectangle {
        id: card

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Config.border.thickness + VT.Theme.marginPx
        anchors.bottomMargin: Config.border.thickness + VT.Theme.marginPx

        // Toasts.qml:26 -- the stack's width, which each ToastItem fills.
        implicitWidth: Tokens.sizes.utilities.toastWidth - Tokens.padding.medium * 2
        // ToastItem.qml:16
        implicitHeight: layout.implicitHeight + Tokens.padding.large

        radius: Tokens.rounding.large          // ToastItem.qml:18
        color: VT.Theme.bgColor
        border.width: 1
        border.color: panel.stateColor

        Behavior on color { VT.CAnim {} }
        Behavior on border.color { VT.CAnim {} }

        // Entry/exit copied from caelestia's toasts (Toasts.qml:80-81, 105-130):
        // opacity and scale together, 0 -> 1 in, and out to opacity 0 / scale 0.7.
        // Not a slide -- the toasts do not translate, so neither does this.
        opacity: panel.active ? 1 : 0
        scale: panel.active ? 1 : 0.7

        Behavior on opacity { VT.Anim { type: VT.Anim.DefaultEffects } }
        Behavior on scale { VT.Anim {} }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.small        // ToastItem.qml:53-55
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            // Icon chip. Same square-from-height trick the toast uses.
            Rectangle {
                id: iconChip

                radius: Tokens.rounding.large
                color: VT.Colours.palette.m3surfaceContainerHigh
                implicitWidth: implicitHeight
                implicitHeight: stateIcon.implicitHeight + Tokens.padding.large

                Behavior on color { VT.CAnim {} }

                VT.MaterialIcon {
                    id: stateIcon

                    anchors.centerIn: parent
                    // Material Symbols names, the same vocabulary caelestia's
                    // toasts use ("keyboard", "rule_settings"). Nerd Font
                    // codepoints render as tofu here -- wrong font entirely.
                    text: panel.daemonState === "transcribing" ? "graphic_eq" : "mic"
                    color: panel.stateColor
                    fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()

                    Behavior on color { VT.CAnim {} }

                    SequentialAnimation on opacity {
                        running: panel.daemonState === "transcribing"
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 550; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0;  duration: 550; easing.type: Easing.InOutQuad }
                    }
                }
            }

            // Text column, mirroring ToastItem.qml:94-129. This is what makes
            // the card the same height as a toast: the toast is sized by its
            // title + message lines, not by the icon chip, so an icon-only card
            // came out visibly shorter. The visualiser occupies the line the
            // message would.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: panel.daemonState === "transcribing" ? qsTr("Transcribing")
                        : panel.daemonState === "streaming"    ? qsTr("Streaming")
                        :                                        qsTr("Listening")
                    color: VT.Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight

                    Behavior on color { VT.CAnim {} }
                }

                Item {
                    id: barArea

                    Layout.fillWidth: true
                    // Same height a body.small line would take, so the column
                    // totals what the toast's two lines total.
                    implicitHeight: bodyMetrics.implicitHeight

                    Text {
                        id: bodyMetrics
                        visible: false
                        text: "M"
                        font: Tokens.font.body.small
                    }

                    readonly property int barWidth: 3
                    readonly property int barGap: 3
                    readonly property int barMaxHeight: Math.max(6, height)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: barArea.barGap

                        Repeater {
                            model: panel.barCount

                            Rectangle {
                                required property int index

                                readonly property real level: panel.levels.length > index
                                    ? panel.levels[index] : 0

                                width: barArea.barWidth
                                radius: width / 2
                                height: Math.max(width, level * barArea.barMaxHeight)
                                anchors.verticalCenter: parent.verticalCenter

                                color: (panel.listening && panel.audio && !panel.audio.vad)
                                    ? VT.Theme.idleColor : VT.Theme.waveformColor
                                opacity: (panel.listening && panel.audio && !panel.audio.vad) ? 0.55 : 1.0

                                Behavior on height {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                }
                                Behavior on color { VT.CAnim {} }
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
