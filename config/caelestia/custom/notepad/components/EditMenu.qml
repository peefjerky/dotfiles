import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.services

// Right-click menu for the text controls.
//
// Qt 6.9+ gives TextArea/TextField a built-in context menu, but it is drawn by the
// Basic style, whose Menu background is a bare `Rectangle` with a border and no
// radius -- hence the sharp corners. Assigning `ContextMenu.menu` replaces it
// outright, which is cheaper than switching the whole app to the Material style
// and then fighting its palette to match matugen.
//
// Caelestia's own components/controls/Menu.qml was not reusable here: it is a
// dropdown anchored to an `attachTo` item and imports qs.modules.drawers, which
// only resolves inside caelestia's own config.
Menu {
    id: root

    required property Item target

    // Popups are their own window by default and would escape the layer surface;
    // Item keeps it inside the panel where it can be clipped and themed.
    popupType: Popup.Item

    padding: Tokens.padding.extraSmall
    margins: Tokens.padding.small

    background: Rectangle {
        implicitWidth: 220
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
    }

    Action {
        text: "Cut"
        enabled: root.target.selectedText.length > 0
        onTriggered: root.target.cut()
    }

    Action {
        text: "Copy"
        enabled: root.target.selectedText.length > 0
        onTriggered: root.target.copy()
    }

    Action {
        text: "Paste"
        enabled: root.target.canPaste
        onTriggered: root.target.paste()
    }

    Action {
        text: "Select all"
        enabled: root.target.length > 0
        onTriggered: root.target.selectAll()
    }

    delegate: MenuItem {
        id: item

        implicitHeight: 38
        padding: Tokens.padding.medium

        contentItem: StyledText {
            text: item.text
            font: Tokens.font.body.small
            color: item.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: Tokens.rounding.medium
            // The 8% state layer caelestia uses everywhere, rather than the
            // Basic style's flat highlight bar.
            color: Qt.alpha(Colours.palette.m3onSurface, item.highlighted && item.enabled ? 0.08 : 0)

            Behavior on color {
                CAnim {}
            }
        }
    }
}
