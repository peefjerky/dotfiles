import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

Flickable {
    id: root

    property string selection

    function focusEditor(): void {
        area.forceActiveFocus();
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    TextArea.flickable: TextArea {
        id: area

        // Deliberately not `text: Store.content`. A binding there would be broken
        // by the first keystroke (typing writes the property directly), leaving
        // the editor permanently detached from the store. Explicit two-way sync
        // with an equality guard keeps both directions working and can't loop.
        Component.onCompleted: text = Store.content

        onTextChanged: Store.content = text
        onSelectedTextChanged: root.selection = selectedText

        wrapMode: TextArea.Wrap
        font: Tokens.font.mono.small
        color: Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        placeholderText: "Write markdown…"
        placeholderTextColor: Colours.palette.m3outline
        background: null

        ContextMenu.menu: EditMenu {
            target: area
        }

        Connections {
            target: Store

            function onContentChanged(): void {
                if (area.text !== Store.content)
                    area.text = Store.content;
            }
        }
    }

    ScrollBar.vertical: ScrollBar {}
}
