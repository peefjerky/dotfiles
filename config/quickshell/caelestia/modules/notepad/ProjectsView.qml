pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.notepad.services

Item {
    id: root

    function focusSearch(): void {
        search.forceActiveFocus();
        search.selectAll();
    }

    property string filter

    readonly property var shown: Projects.repos.filter(r => !root.filter || (r.group + "/" + r.name).toLowerCase().includes(root.filter.toLowerCase()))

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        hint: "Filter projects…"

        onTextChanged: root.filter = text
        onMoveUp: list.decrementCurrentIndex()
        onMoveDown: list.incrementCurrentIndex()
        onAccepted: if (list.currentIndex >= 0 && root.shown.length) Projects.terminal(root.shown[list.currentIndex].path)
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: root.shown.length === 0
        icon: "folder_code"
        title: Projects.busy ? "Scanning…" : "No repos found"
        detail: "Git repositories under ~/Projects appear here. Enter or a click opens a terminal there, right-click opens the folder."
    }

    VerticalFadeListView {
        id: list

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

        // The Enter target. Keyboard-driven, so it jumps rather than glides.
        highlightMoveDuration: 0
        highlightResizeDuration: 0
        highlight: StyledRect {
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHigh
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

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

                // A bare number in a pill said nothing; it is the count of files
                // with uncommitted changes, so it says so.
                visible: row.modelData.dirty > 0
                implicitWidth: dirtyLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: 24
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                StyledText {
                    id: dirtyLabel

                    anchors.centerIn: parent
                    text: `${row.modelData.dirty} uncommitted`
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onPrimaryContainer
                }
            }
        }
    }
}
