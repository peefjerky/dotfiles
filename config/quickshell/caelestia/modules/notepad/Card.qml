pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

// Panel contents only. Position, size, reveal animation and the blob background
// all belong to Wrapper.qml -- the same split caelestia uses, where `Panels`
// holds content and `ContentWindow` holds the blobs and drives the geometry.
Item {
    id: root

    // Live in NotepadState, so they outlive this Card (it is torn down with the
    // panel's Loader on close). Ctrl+1..7, the rail, or `ipc call notepad mode`.
    readonly property int mode: NotepadState.mode
    readonly property bool rawMode: NotepadState.rawMode

    property real rawProgress: rawMode ? 1 : 0

    // Whatever is selected in whichever editor is live, for the dictionary.
    readonly property string selection: rawMode ? editor.selection : rendered.selection

    function requestMode(i: int): void {
        NotepadState.mode = i;
    }

    function focusDict(seed: string): void {
        dict.focusSearch(seed);
    }

    function save(): void {
        Store.exportSnapshot();
    }

    // Put the keyboard where the tab's work is: the search field on every list
    // tab, the editor on the note. Switching tabs and typing is then one motion.
    function focusCurrent(): void {
        if (mode === 0 && rawMode)
            editor.focusEditor();
        else if (mode === 0)
            rendered.forceActiveFocus();
        else if (mode === 4)
            dict.focusSearch("");
        else if ([1, 3, 5, 6].includes(mode))
            [null, clipboard, null, files, null, projects, emoji][mode].focusSearch();
        else
            root.forceActiveFocus();
    }

    onModeChanged: {
        if (mode === 1)
            Clip.refresh();
        else if (mode === 5)
            Projects.refresh();
        else if (mode === 6)
            Emoji.load();
        focusCurrent();
    }

    Component.onCompleted: {
        // Opening straight onto a list tab still needs its data.
        if (mode !== 0)
            modeChanged();
        else
            focusCurrent();
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

        focusCurrent();
    }

    // Swallow clicks so they don't reach caelestia's Interactions layer underneath,
    // which treats presses in the border hole as drawer drags.
    MouseArea {
        anchors.fill: parent
    }

    // The rail is chrome and runs edge to edge; only the content is inset. Above
    // the content so its tooltips are not painted over.
    Tabs {
        id: rail

        z: 1
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
        anchors.bottomMargin: Tokens.padding.large

        spacing: Tokens.spacing.large

        Header {
            // Above the views, so its tooltips are too.
            z: 1
            Layout.fillWidth: true
            rawMode: root.rawMode
            mode: root.mode

            onToggleMode: NotepadState.rawMode = !NotepadState.rawMode
            onRequestSave: root.save()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Pane {
                index: 0

                RenderedView {
                    id: rendered

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    source: Store.content
                    opacity: 1 - root.rawProgress
                    visible: opacity > 0
                }

                RawEditor {
                    id: editor

                    // Same column as the rendered view, so the text sits in one
                    // place while the two cross-fade.
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: rendered.measure + Tokens.padding.large
                    opacity: root.rawProgress
                    visible: opacity > 0
                }
            }

            Pane {
                index: 1

                ClipboardView {
                    id: clipboard

                    anchors.fill: parent
                }
            }

            Pane {
                index: 2

                ColourView {
                    anchors.fill: parent
                }
            }

            Pane {
                index: 3

                FilesView {
                    id: files

                    anchors.fill: parent
                }
            }

            Pane {
                index: 4

                DictView {
                    id: dict

                    anchors.fill: parent
                }
            }

            Pane {
                index: 5

                ProjectsView {
                    id: projects

                    anchors.fill: parent
                }
            }

            Pane {
                index: 6

                EmojiView {
                    id: emoji

                    anchors.fill: parent
                }
            }
        }
    }

    SaveToast {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.extraLarge
    }

    // One view per tab. The incoming pane rises from the side of the rail it sits
    // on and the outgoing one leaves toward the other, so the content moves the
    // way the indicator does -- down the rail, the content scrolls up. 10px and
    // the short standard curve: it orients, it does not perform, because tab
    // switches are constant and half come from the keyboard.
    //
    // The exit is the faster half. Two panes at equal opacity mid-switch read as
    // a double exposure; leaving quickly means the overlap is mostly the new one.
    component Pane: Item {
        id: pane

        required property int index

        readonly property bool current: root.mode === index

        anchors.fill: parent
        opacity: current ? 1 : 0
        visible: opacity > 0
        enabled: current

        transform: Translate {
            y: pane.current ? 0 : pane.index > root.mode ? 10 : -10

            Behavior on y {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: pane.current ? Anim.DefaultEffects : Anim.FastEffects
            }
        }
    }
}
