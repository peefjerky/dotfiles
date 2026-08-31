pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

Item {
    id: root

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        hint: "Search emoji and symbols…"

        onTextChanged: Emoji.filter = text
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: Emoji.shown.length === 0
        icon: "mood"
        title: Emoji.loaded ? "Nothing matched" : "Loading…"
        detail: Emoji.loaded ? "Search by name — try \"arrow\", \"check\" or \"fire\". Click to copy." : ""
    }

    GridView {
        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.small

        model: Emoji.shown
        cellWidth: 58
        cellHeight: 58
        clip: true
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        delegate: Item {
            id: cell

            required property var modelData

            width: 58
            height: 58

            StyledRect {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.extraSmall

                radius: Tokens.rounding.medium
                color: "transparent"

                StyledText {
                    anchors.centerIn: parent
                    text: cell.modelData.glyph
                    font.pointSize: 22
                    color: Colours.palette.m3onSurface
                }

                StateLayer {
                    id: cellHover

                    radius: parent.radius
                    onClicked: Emoji.copy(cell.modelData.glyph)
                }

                // Tucked into the corner rather than centred, so it never hides
                // the glyph you are trying to identify.
                MaterialIcon {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2

                    text: "content_copy"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    opacity: cellHover.containsMouse ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }
        }
    }
}
