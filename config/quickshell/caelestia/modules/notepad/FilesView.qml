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

        hint: "Find a file under ~"

        onTextChanged: Files.search(text)
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: Files.results.length === 0
        icon: "search"
        title: Files.busy ? "Searching…" : search.text.length < 2 ? "Find a file" : "Nothing matched"
        detail: search.text.length < 2 ? "Type at least two characters. Enter opens it, right-click reveals the folder." : ""
    }

    ListView {
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

        ScrollBar.vertical: ScrollBar {}

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
