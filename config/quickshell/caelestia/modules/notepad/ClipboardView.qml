pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

Item {
    id: root

    property string filter

    readonly property var shown: Clip.entries.filter(e => !root.filter || e.preview.toLowerCase().includes(root.filter.toLowerCase()))

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: clearAll.left
        anchors.rightMargin: Tokens.spacing.medium

        hint: "Search clipboard…"

        onTextChanged: root.filter = text
    }

    StyledText {
        id: clearAll

        anchors.right: parent.right
        anchors.verticalCenter: search.verticalCenter

        visible: Clip.entries.length > 0
        text: "Clear all"
        font: Tokens.font.label.small
        color: Colours.palette.m3error

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Tokens.padding.small
            cursorShape: Qt.PointingHandCursor
            onClicked: Clip.wipe()
        }
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: root.shown.length === 0
        icon: "content_paste"
        title: Clip.entries.length ? "Nothing matched" : "Clipboard is empty"
        detail: Clip.entries.length ? "" : "Anything you copy shows up here, images included. Click a row to copy it back."
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
        // Only rows in view exist, so a 124-entry history decodes at most a
        // screenful of thumbnails rather than all of them.
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        delegate: StyledRect {
            id: row

            required property var modelData

            width: ListView.view.width
            implicitHeight: Math.max(44, content.implicitHeight + Tokens.padding.small * 2)
            radius: Tokens.rounding.medium
            color: "transparent"

            StateLayer {
                id: rowHover

                onClicked: {
                    Clip.copy(row.modelData.id);
                    root.filter = "";
                    search.text = "";
                }
            }

            // Says what a click will do. Sits left of the delete control so the
            // two never overlap.
            MaterialIcon {
                anchors.right: del.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.medium

                text: "content_copy"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                opacity: rowHover.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Loader {
                id: content

                anchors.left: parent.left
                anchors.right: del.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                // Clears both the copy hint and the delete control.
                anchors.rightMargin: Tokens.padding.extraLarge * 2

                sourceComponent: row.modelData.image ? thumb : line
            }

            Component {
                id: line

                StyledText {
                    text: row.modelData.preview
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
            }

            Component {
                id: thumb

                Row {
                    spacing: Tokens.spacing.small

                    Image {
                        id: img

                        // thumbsReady in the URL busts Qt's image cache once the
                        // decode pass has actually written the file.
                        source: `file://${Clip.thumbPath(row.modelData.id)}?v=${Clip.thumbsReady}`
                        // Caps decode *and* memory: Qt scales at load, so a 2557px
                        // screenshot never becomes a full-size texture.
                        sourceSize.height: 56
                        fillMode: Image.PreserveAspectFit
                        height: 56
                        width: Math.min(120, row.modelData.w / Math.max(1, row.modelData.h) * 56)
                        asynchronous: true
                        cache: true

                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${row.modelData.w}×${row.modelData.h}`
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                    }
                }
            }

            MaterialIcon {
                id: del

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.small

                text: "close"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.small
                opacity: delArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MouseArea {
                    id: delArea

                    anchors.fill: parent
                    anchors.margins: -Tokens.padding.small
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Clip.remove(row.modelData.id)
                }
            }
        }
    }
}
