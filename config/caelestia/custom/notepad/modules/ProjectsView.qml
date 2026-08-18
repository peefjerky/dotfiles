pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property string filter

    readonly property var shown: Projects.repos.filter(r => !root.filter || (r.group + "/" + r.name).toLowerCase().includes(root.filter.toLowerCase()))

    SearchField {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        hint: "Filter projects…"

        onTextChanged: root.filter = text
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: root.shown.length === 0
        icon: "folder_code"
        title: Projects.busy ? "Scanning…" : "No repos found"
        detail: "Git repositories under ~/Projects appear here. Click opens a terminal there, right-click opens the folder."
    }

    ListView {
        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.small

        model: root.shown
        clip: true
        spacing: Tokens.spacing.extraSmall
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        delegate: StyledRect {
            id: row

            required property var modelData

            width: ListView.view.width
            implicitHeight: 52
            radius: Tokens.rounding.medium
            color: "transparent"

            StateLayer {
                // Click opens a terminal there, right-click opens the folder.
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? Projects.reveal(row.modelData.path) : Projects.terminal(row.modelData.path)
            }

            Column {
                anchors.left: parent.left
                anchors.right: badge.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.small

                spacing: 0

                StyledText {
                    width: parent.width
                    text: row.modelData.name
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: row.modelData.group
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                    elide: Text.ElideMiddle
                }
            }

            StyledRect {
                id: badge

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.medium

                visible: row.modelData.dirty > 0
                implicitWidth: Math.max(26, dirtyLabel.implicitWidth + Tokens.padding.small * 2)
                implicitHeight: 24
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                StyledText {
                    id: dirtyLabel

                    anchors.centerIn: parent
                    text: row.modelData.dirty
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onPrimaryContainer
                }
            }
        }
    }
}
