import QtQuick
import Caelestia.Config
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.notepad.services
import "services/Markdown.js" as Md

// Rendered markdown, one TextEdit for the whole note.
//
// Deliberately not a per-line editor: rendering each line into its own item and
// swapping the focused one for a TextArea broke cursor behaviour (arrow keys and
// selection stop at line boundaries, because each line is a separate control) and
// cost one item per line. Ctrl+E swaps to the raw editor instead.
VerticalFadeFlickable {
    id: root

    required property string source

    readonly property string selection: label.selectedText

    // The prose column. A 900px panel at body size ran ~95 characters a line,
    // well past comfortable reading; this lands around 75 with spaces and
    // punctuation, and the raw editor uses the same column, so toggling Ctrl+E
    // cross-fades text that stays put. Measured on real lowercase rather than
    // averageCharacterWidth, which counts capitals and overshoots by ~15%.
    readonly property real measure: Math.min(width, metrics.advanceWidth("abcdefghijklmnopqrstuvwxyz") / 26 * 66)

    // Tables are the one thing Markdown.js leaves to Qt's importer.
    readonly property bool qtImporter: Md.hasTable(source)

    readonly property string rendered: qtImporter ? withTaskLinks(source) : Md.render(source, {
        size: Tokens.font.body.medium.pointSize > 0 ? Tokens.font.body.medium.pointSize : Tokens.font.body.medium.pixelSize * 0.75,
        family: Tokens.font.body.medium.family,
        mono: Tokens.font.mono.small.family,
        icon: Tokens.font.icon.small.family,
        fg: Colours.palette.m3onSurface,
        muted: Colours.palette.m3onSurfaceVariant,
        accent: Colours.palette.m3primary,
        code: Colours.palette.m3surfaceContainerHigh,
        rule: Colours.palette.m3outlineVariant
    })

    // Native path only: task checkboxes rewritten as links so they stay
    // clickable -- Text can report which link was hit, but cannot map a click
    // back to a source line otherwise. Markdown.js emits the same tg: links.
    function withTaskLinks(src: string): string {
        const lines = src.split("\n");
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
    contentHeight: label.implicitHeight + Tokens.padding.large
    clip: true
    fadeAmount: 0.06
    boundsBehavior: Flickable.StopAtBounds

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    FontMetrics {
        id: metrics

        font: Tokens.font.body.medium
    }

    // A read-only TextEdit rather than Text: Text cannot select, and selection is
    // what feeds Ctrl+D's lookup.
    TextEdit {
        id: label

        width: root.measure

        text: root.rendered
        readOnly: true
        textFormat: root.qtImporter ? TextEdit.MarkdownText : TextEdit.RichText
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

        // Rich text has no pointer cursor over links of its own.
        HoverHandler {
            cursorShape: label.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
        }
    }
}
