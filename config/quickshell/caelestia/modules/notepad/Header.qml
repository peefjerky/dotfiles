pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

RowLayout {
    id: root

    required property bool rawMode
    required property int mode

    signal toggleMode
    signal requestSave

    spacing: Tokens.spacing.medium

    StyledText {
        Layout.fillWidth: true

        text: ["Notepad", "Clipboard", "Colours", "Files", "Dictionary", "Projects", "Emoji"][root.mode]
        font: Tokens.font.title.small
        color: Colours.palette.m3onSurface
    }

    // Quiet status: size of the note, and whether autosave has caught up.
    StyledText {
        readonly property var words: Store.content.match(/\S+/g)
        readonly property int count: words ? words.length : 0

        visible: root.mode === 0
        text: `${count} ${count === 1 ? "word" : "words"} · ${Store.pending ? "Saving…" : "Saved"}`
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }

    // Preview / Edit as a segmented control rather than one icon that showed
    // the mode you would switch *to* -- which read as the current state half
    // the time. Both options are named and the current one is filled.
    StyledRect {
        id: segments

        readonly property real segWidth: Math.max(preview.implicitWidth, edit.implicitWidth) + Tokens.padding.large * 2

        visible: root.mode === 0
        implicitWidth: segWidth * 2 + 4 * 2
        implicitHeight: 36
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        // Ctrl+E flips this as often as a click does, so it moves on the short
        // standard curve, not an expressive one.
        StyledRect {
            x: 4 + (root.rawMode ? segments.segWidth : 0)
            y: 4
            width: segments.segWidth
            height: parent.height - 8
            radius: Tokens.rounding.full
            color: Colours.palette.m3secondaryContainer

            Behavior on x {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }

        Row {
            x: 4
            y: 4

            Segment {
                id: preview

                label: "Preview"
                selected: !root.rawMode
            }

            Segment {
                id: edit

                label: "Edit"
                selected: root.rawMode
            }
        }

        StateLayer {
            id: segHover

            radius: Tokens.rounding.full
            onClicked: root.toggleMode()
        }

        Tip {
            anchors.top: parent.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter

            hovered: segHover.containsMouse
            text: root.rawMode ? "Back to preview" : "Edit the markdown"
            shortcut: "Ctrl+E"
            origin: Item.Top
        }
    }

    StyledRect {
        visible: root.mode === 0
        implicitWidth: 36
        implicitHeight: 36
        radius: Tokens.rounding.full
        color: "transparent"

        MaterialIcon {
            anchors.centerIn: parent

            // Export, not save: the note autosaves continuously, and this writes
            // a timestamped copy to ~/Documents/Notes. A floppy disk promised the
            // wrong thing.
            text: "file_export"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StateLayer {
            id: exportHover

            onClicked: root.requestSave()
        }

        Tip {
            anchors.top: parent.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.right: parent.right

            hovered: exportHover.containsMouse
            text: "Export a copy to ~/Documents/Notes"
            shortcut: "Ctrl+S"
            origin: Item.TopRight
        }
    }

    component Segment: StyledText {
        required property string label
        required property bool selected

        width: segments.segWidth
        height: segments.implicitHeight - 8
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: label
        font: Tokens.font.label.large
        color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
    }
}
