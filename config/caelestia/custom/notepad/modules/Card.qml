pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Panel contents only. Position, size, reveal animation and the blob background
// all belong to NotepadWindow -- the same split caelestia uses, where `Panels`
// holds content and `ContentWindow` holds the blobs and drives the geometry.
Item {
    id: root

    // 0 note, 1 clipboard, 2 colours, 3 files, 4 dictionary, 5 projects,
    // 6 emoji. Ctrl+1..7, or the tabs.
    property int mode

    property bool rawMode

    property real rawProgress: rawMode ? 1 : 0

    // Whatever is selected in whichever editor is live, for the dictionary.
    readonly property string selection: rawMode ? editor.selection : rendered.selection

    signal requestMode(index: int)

    function focusDict(seed: string): void {
        dict.focusSearch(seed);
    }

    function save(): void {
        Store.exportSnapshot();
    }

    // An Effects curve, not a Spatial one: this is a pure opacity cross-fade with
    // no movement, which is the distinction caelestia draws between the two sets.
    Behavior on rawProgress {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    onRawModeChanged: {
        // Carry roughly the same place in the document across the switch. An exact
        // anchor isn't achievable -- rendered markdown and raw source have
        // unrelated layouts -- so this matches the normalised scroll fraction.
        const from = rawMode ? rendered : editor;
        const to = rawMode ? editor : rendered;
        const span = Math.max(1, from.contentHeight - from.height);
        const fraction = Math.max(0, Math.min(1, from.contentY / span));
        Qt.callLater(() => {
            to.contentY = fraction * Math.max(0, to.contentHeight - to.height);
        });

        if (rawMode)
            editor.focusEditor();
    }

    // Swallow clicks so they don't reach the dismiss handler on the backdrop.
    MouseArea {
        anchors.fill: parent
    }

    // The rail is chrome and runs edge to edge; only the content is inset.
    Tabs {
        id: rail

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        current: root.mode
        onSelected: i => root.requestMode(i)
    }

    ColumnLayout {
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.extraLarge
        anchors.bottomMargin: Tokens.padding.extraLarge

        spacing: Tokens.spacing.medium

        Header {
            Layout.fillWidth: true
            rawMode: root.rawMode
            mode: root.mode

            onToggleMode: root.rawMode = !root.rawMode
            onRequestSave: root.save()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RenderedView {
                id: rendered

                anchors.fill: parent
                source: Store.content
                opacity: root.mode === 0 ? 1 - root.rawProgress : 0
                visible: opacity > 0
            }

            RawEditor {
                id: editor

                anchors.fill: parent
                opacity: root.mode === 0 ? root.rawProgress : 0
                visible: opacity > 0
            }

            ClipboardView {
                anchors.fill: parent
                opacity: root.mode === 1 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            ColourView {
                anchors.fill: parent
                opacity: root.mode === 2 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            FilesView {
                anchors.fill: parent
                opacity: root.mode === 3 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            ProjectsView {
                anchors.fill: parent
                opacity: root.mode === 5 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            EmojiView {
                anchors.fill: parent
                opacity: root.mode === 6 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            DictView {
                id: dict

                anchors.fill: parent
                opacity: root.mode === 4 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }

    SaveToast {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.extraLarge
    }
}
