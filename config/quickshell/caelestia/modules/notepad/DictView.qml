pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

// Dictionary, as a panel tab.
//
// It used to be a floating blob above the panel. That looked right but shared the
// panel's reveal: closing with Cmd+G animated the panel while the box was still
// laid out against its old position, so the close skipped. As a tab it inherits
// the panel's animation wholesale and there is nothing left to desynchronise.
Item {
    id: root

    function focusSearch(seed: string): void {
        if (seed)
            search.text = seed;
        search.forceActiveFocus();
        search.selectAll();
    }

    SearchBox {
        id: search

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        hint: "Look up a word…"

        onTextChanged: Dict.lookup(text)
    }

    EmptyState {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Tokens.spacing.large

        visible: !Dict.entries.length
        icon: !Dict.installed ? "extension_off" : "book_2"
        title: !Dict.installed ? "Dictionary not installed" : Dict.busy ? "Looking up…" : search.text.length ? "No entry found" : "Look up a word"
        detail: !Dict.installed ? "Run: yay -S --needed sdcv stardict-wordnet" : search.text.length ? "" : "Select a word anywhere in the note and press Ctrl+D to look it up here."
    }

    Flickable {
        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.large

        contentWidth: width
        contentHeight: entry.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: Dict.entries.length > 0

        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: entry

            width: parent.width
            spacing: Tokens.spacing.small

            // The headword, set large and in the accent colour.
            StyledText {
                Layout.fillWidth: true

                text: Dict.word
                font: Tokens.font.headline.small
                color: Colours.palette.m3primary
            }

            Repeater {
                model: Dict.entries

                ColumnLayout {
                    id: group

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.extraSmall

                    // "[pronunciation] noun." -- WordNet carries no phonetics, so
                    // the bracketed part only appears if a dictionary provides it.
                    StyledText {
                        Layout.fillWidth: true

                        textFormat: Text.StyledText
                        text: `<b>${group.modelData.pos}.</b>`
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }

                    Repeater {
                        model: group.modelData.senses

                        ColumnLayout {
                            id: sense

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.padding.medium
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true

                                text: `${sense.modelData.n}. ${sense.modelData.text}`
                                font: Tokens.font.body.medium
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: sense.modelData.examples

                                StyledText {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.leftMargin: Tokens.padding.medium

                                    text: `“${modelData}”`
                                    // Members individually: assigning `font` and
                                    // `font.italic` both is a QML conflict.
                                    font.family: Tokens.font.body.small.family
                                    font.pointSize: Tokens.font.body.small.pointSize
                                    font.italic: true
                                    color: Colours.palette.m3onSurfaceVariant
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
