import QtQuick
import Caelestia.Config
import qs.services
import qs.modules.notepad.services

// Rendered markdown, one Text for the whole note.
//
// Deliberately not a per-line editor: rendering each line into its own item and
// swapping the focused one for a TextArea broke cursor behaviour (arrow keys and
// selection stop at line boundaries, because each line is a separate control) and
// cost one item per line. Ctrl+E swaps to the raw editor instead.
Flickable {
    id: root

    required property string source

    readonly property string selection: label.selectedText

    // Task checkboxes are rewritten as markdown links so they stay clickable
    // without needing per-line items -- Text can report which link was hit, but
    // cannot map a click back to a source line otherwise.
    readonly property string rendered: {
        const lines = root.source.split("\n");
        for (let i = 0; i < lines.length; i++)
            lines[i] = lines[i].replace(/^(\s*[-*+]\s+)\[([ xX])\]/, (m, bullet, state) => `${bullet}[${state === " " ? "☐" : "☑"}](tg:${i})`);
        return lines.join("\n");
    }

    function toggleTask(i: int): void {
        const lines = Store.content.split("\n");
        const m = lines[i].match(/^(\s*[-*+]\s+)\[([ xX])\]/);
        if (!m)
            return;
        lines[i] = lines[i].replace(/^(\s*[-*+]\s+)\[([ xX])\]/, `$1[${m[2] === " " ? "x" : " "}]`);
        Store.content = lines.join("\n");
    }

    contentWidth: width
    contentHeight: label.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // A read-only TextEdit rather than Text: Text cannot select, and selection is
    // what feeds Ctrl+D's lookup. Everything else is identical.
    TextEdit {
        id: label

        width: root.width

        text: root.rendered
        readOnly: true
        // Qt 6.11's markdown is md4c-backed: headings, emphasis, lists, task
        // checkboxes, quotes, links, tables and code all parse. There is no CSS,
        // so styling goes through the properties below and `palette` -- and code
        // fences get Qt's generic fixed font rather than Tokens.font.mono, which
        // is baked into the document by the importer and can't be overridden here.
        textFormat: TextEdit.MarkdownText
        wrapMode: TextEdit.WordWrap
        font: Tokens.font.body.medium
        color: Colours.palette.m3onSurface
        // NativeRendering (StyledText's default) subpixel-snaps glyphs, which
        // fights the sub-pixel positions this card sits at mid-animation.
        renderType: TextEdit.QtRendering

        // Lets Ctrl+D look a word up straight from the rendered view.
        selectByMouse: true
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary

        palette.link: Colours.palette.m3primary

        onLinkActivated: link => {
            if (link.startsWith("tg:"))
                root.toggleTask(parseInt(link.slice(3)));
            else
                Qt.openUrlExternally(link);
        }
    }
}
