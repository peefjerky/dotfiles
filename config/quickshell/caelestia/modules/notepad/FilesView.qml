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

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        hint: "Find a file under ~"

        onTextChanged: Files.search(text)
        onMoveUp: list.decrementCurrentIndex()
        onMoveDown: list.incrementCurrentIndex()
        onAccepted: if (list.currentIndex >= 0 && Files.results.length) Files.open(Files.results[list.currentIndex].path)
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: Files.results.length === 0
        icon: "search"
        title: Files.busy ? "Searching…" : search.text.length < 2 ? "Find a file" : "Nothing matched"
        detail: search.text.length < 2 ? "Type at least two characters. Enter opens it, right-click reveals the folder." : ""
    }

    VerticalFadeListView {
        id: list

        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.small

        model: Files.results
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
                // Plain click opens the file, right-click opens its folder.
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? Files.reveal(row.modelData.path) : Files.open(row.modelData.path)
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium

                spacing: 0

                StyledText {
                    width: parent.width
                    text: row.modelData.name
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideMiddle
                }

                StyledText {
                    width: parent.width
                    text: row.modelData.dir
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
