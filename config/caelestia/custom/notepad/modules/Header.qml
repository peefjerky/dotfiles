pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property bool rawMode
    required property int mode

    signal toggleMode
    signal requestSave

    spacing: Tokens.spacing.small

    StyledText {
        Layout.fillWidth: true

        text: ["Notepad", "Clipboard", "Colours", "Files", "Dictionary", "Projects", "Emoji"][root.mode]
        font: Tokens.font.title.small
        color: Colours.palette.m3onSurface
    }

    StyledText {
        readonly property var words: Store.content.match(/\S+/g)

        visible: root.mode === 0
        text: `${words ? words.length : 0} words`
        font: Tokens.font.label.small
        color: Colours.palette.m3outline
    }

    StyledText {
        // Quiet hint rather than a tooltip -- the shortcut is the fast path and
        // there's no reason to make the user hunt for it.
        visible: root.mode === 0
        text: root.rawMode ? "Ctrl+E to preview" : "Ctrl+E to edit"
        font: Tokens.font.label.small
        color: Colours.palette.m3outline
    }

    IconButton {
        visible: root.mode === 0
        iconName: root.rawMode ? "visibility" : "edit"
        onActivated: root.toggleMode()
    }

    IconButton {
        visible: root.mode === 0
        iconName: "save"
        onActivated: root.requestSave()
    }

    component IconButton: StyledRect {
        id: btn

        required property string iconName

        signal activated

        implicitWidth: 42
        implicitHeight: 42
        radius: Tokens.rounding.full
        color: "transparent"

        MaterialIcon {
            anchors.centerIn: parent

            text: btn.iconName
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        // Material state layer: 8% hover tint plus the expanding press ripple,
        // copied from caelestia so the feel is identical rather than similar.
        StateLayer {
            onClicked: btn.activated()
        }
    }
}
