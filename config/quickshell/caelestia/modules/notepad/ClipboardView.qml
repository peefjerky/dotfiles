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

    property string filter

    readonly property var shown: Clip.entries.filter(e => !root.filter || e.preview.toLowerCase().includes(root.filter.toLowerCase()))

    function focusSearch(): void {
        search.forceActiveFocus();
    }

    function copy(entry: var): void {
        Clip.copy(entry.id);
        NotepadState.toast(entry.image ? "Image copied" : "Copied");
        search.text = "";
    }

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: clearAll.left
        anchors.rightMargin: Tokens.spacing.medium

        hint: "Search clipboard…"

        onTextChanged: root.filter = text
        onMoveUp: list.decrementCurrentIndex()
        onMoveDown: list.incrementCurrentIndex()
        onAccepted: if (list.currentIndex >= 0 && root.shown.length) root.copy(root.shown[list.currentIndex])
    }

    // Wiping the whole history is the one irreversible action in the panel, so it
    // takes two clicks: the first arms it and says so, and it disarms itself if the
    // second never comes. It is neutral until armed -- a permanently red label
    // reads as an error state, not as a control.
    StyledText {
        id: clearAll

        property bool armed

        anchors.right: parent.right
        anchors.verticalCenter: search.verticalCenter

        visible: Clip.entries.length > 0
        text: armed ? "Click again to clear" : "Clear all"
        font: Tokens.font.label.medium
        color: armed ? Colours.palette.m3error : clearArea.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant

        Timer {
            running: clearAll.armed
            interval: 3000
            onTriggered: clearAll.armed = false
        }

        MouseArea {
            id: clearArea

            anchors.fill: parent
            anchors.margins: -Tokens.padding.small
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (clearAll.armed) {
                    clearAll.armed = false;
                    Clip.wipe();
                    NotepadState.toast("Clipboard history cleared");
                } else {
                    clearAll.armed = true;
                }
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: root.shown.length === 0
        icon: "content_paste"
        title: Clip.entries.length ? "Nothing matched" : "Clipboard is empty"
        detail: Clip.entries.length ? "" : "Anything you copy shows up here, images included. Enter or a click copies it back."
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
        fadeAmount: 0.08
        // Only rows in view exist, so a 124-entry history decodes at most a
        // screenful of thumbnails rather than all of them.
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
            required property int index

            readonly property bool hovered: rowHover.containsMouse || delArea.containsMouse

            width: ListView.view.width
            implicitHeight: Math.max(48, content.implicitHeight + Tokens.padding.small * 2)
            radius: Tokens.rounding.medium
            color: "transparent"

            StateLayer {
                id: rowHover

                onClicked: root.copy(row.modelData)
            }

            Loader {
                id: content

                anchors.left: parent.left
                anchors.right: actions.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium

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
                    spacing: Tokens.spacing.medium

                    StyledClippingRect {
                        width: img.width
                        height: img.height
                        radius: Tokens.rounding.small

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
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${row.modelData.w} × ${row.modelData.h}`
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            // What a click does, and a way to drop the entry. Both appear for the
            // whole row's hover: the delete control used to show only when the
            // pointer was already on it, which made it impossible to find.
            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.small

                spacing: Tokens.spacing.extraSmall
                opacity: row.hovered ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignHCenter

                    text: "content_copy"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledRect {
                    width: 32
                    height: 32
                    radius: Tokens.rounding.full
                    color: delArea.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.12) : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent

                        text: "close"
                        color: delArea.containsMouse ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: delArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clip.remove(row.modelData.id)
                    }
                }
            }
        }
    }
}
