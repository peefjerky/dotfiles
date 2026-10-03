import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Plain M3 tooltip: a name and, where there is one, the shortcut.
//
// The rail is seven bare icons and the header buttons have no labels, so this is
// what makes Ctrl+1..7, Ctrl+E and Ctrl+S discoverable without a help screen.
//
// Timing follows the tooltip-group rule: the first one waits 500ms so sweeping
// the pointer across the rail doesn't flash seven labels, and once one has shown,
// neighbours appear instantly until the pointer has been away for a moment. The
// enter is a short scale from the edge facing the control, the exit is instant --
// attention has already moved on.
StyledRect {
    id: root

    property bool hovered
    property string text
    property string shortcut
    // Which edge points at the control: the tip grows out of that side.
    property int origin: Item.Left

    // Sampled on hover, not bound: Date.now() is not a reactive dependency.
    property bool warm

    readonly property bool shown: hovered && (warm || delay.done)

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: 32
    radius: Tokens.rounding.small
    color: Colours.palette.m3inverseSurface
    z: 100

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    visible: opacity > 0
    transformOrigin: origin

    onShownChanged: if (!shown) NotepadState.tipWarmUntil = Date.now() + 600
    onHoveredChanged: {
        delay.done = false;
        warm = hovered && Date.now() < NotepadState.tipWarmUntil;
        if (hovered)
            delay.restart();
        else
            delay.stop();
    }

    Behavior on opacity {
        enabled: root.shown

        Anim {
            type: Anim.FastEffects
        }
    }

    Behavior on scale {
        enabled: root.shown

        Anim {
            type: Anim.FastEffects
        }
    }

    Timer {
        id: delay

        property bool done

        interval: 500
        onTriggered: done = true
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        StyledText {
            text: root.text
            font: Tokens.font.label.medium
            color: Colours.palette.m3inverseOnSurface
        }

        StyledText {
            visible: root.shortcut.length > 0
            text: root.shortcut
            font: Tokens.font.label.medium
            color: Qt.alpha(Colours.palette.m3inverseOnSurface, 0.6)
        }
    }
}
