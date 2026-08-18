import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.services

// One search field for every view that has one.
//
// Clipboard, Files, Dictionary, Projects and Emoji each hand-rolled this with
// slightly different padding and font sizes. Operate surfaces live or die on a
// consistent component vocabulary -- if the same control looks different on two
// tabs, one of them is wrong.
TextField {
    id: root

    required property string hint

    implicitHeight: 44
    leftPadding: Tokens.padding.medium
    rightPadding: Tokens.padding.medium

    placeholderText: hint
    placeholderTextColor: Colours.palette.m3outline
    font: Tokens.font.body.medium
    color: Colours.palette.m3onSurface
    selectionColor: Colours.palette.m3primary
    selectedTextColor: Colours.palette.m3onPrimary

    background: StyledRect {
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        // Focus is a real state here, not a browser outline.
        border.width: 1
        border.color: root.activeFocus ? Colours.palette.m3primary : "transparent"

        Behavior on border.color {
            CAnim {}
        }
    }

    ContextMenu.menu: EditMenu {
        target: root
    }
}
