pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: pickRow.implicitWidth + Tokens.padding.large * 2
                implicitHeight: 44
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                RowLayout {
                    id: pickRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: Picker.picking ? "hourglass_empty" : "colorize"
                        color: Colours.palette.m3onPrimaryContainer
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Picker.picking ? "Picking…" : "Pick a colour"
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                StateLayer {
                    radius: parent.radius
                    onClicked: Picker.pick()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: Picker.recent.length > 0
                text: "Clear"
                font: Tokens.font.label.small
                color: Colours.palette.m3outline

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Tokens.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Picker.clear()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Picker.recent.length === 0
            text: "Picked colours land here, and go straight to the clipboard."
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        GridView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: Picker.recent
            cellWidth: 108
            cellHeight: 76
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell

                required property string modelData

                width: 108
                height: 76

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.extraSmall

                    radius: Tokens.rounding.medium
                    color: cell.modelData

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Tokens.padding.extraSmall

                        text: cell.modelData
                        font: Tokens.font.label.small
                        // Pick a legible label without knowing the swatch colour:
                        // Qt gives us the luminance directly.
                        color: cell.modelData.hslLightness > 0.5 ? "#000000" : "#ffffff"
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: Picker.copy(cell.modelData)
                    }
                }
            }
        }
    }
}
