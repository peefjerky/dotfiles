pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji and symbol picker.
//
// Parsed from the Unicode emoji-test data that ships with oh-my-zsh, so there is
// no new package to install. Loaded once, lazily, the first time the tab opens.
Singleton {
    id: root

    readonly property string dataPath: "/usr/share/oh-my-zsh/plugins/emoji/emoji-data.txt"

    // [{ glyph, name }]
    property var all: []
    property string filter
    property bool loaded

    // A handful of symbols the emoji tables don't carry but that get looked up
    // constantly anyway.
    readonly property var extras: [
        { glyph: "→", name: "arrow right" },
        { glyph: "←", name: "arrow left" },
        { glyph: "↑", name: "arrow up" },
        { glyph: "↓", name: "arrow down" },
        { glyph: "⇒", name: "arrow double right implies" },
        { glyph: "↔", name: "arrow left right" },
        { glyph: "×", name: "times multiply cross" },
        { glyph: "÷", name: "divide" },
        { glyph: "≈", name: "approximately equal" },
        { glyph: "≠", name: "not equal" },
        { glyph: "≤", name: "less than or equal" },
        { glyph: "≥", name: "greater than or equal" },
        { glyph: "±", name: "plus minus" },
        { glyph: "°", name: "degree" },
        { glyph: "…", name: "ellipsis dots" },
        { glyph: "—", name: "em dash" },
        { glyph: "–", name: "en dash" },
        { glyph: "•", name: "bullet dot" },
        { glyph: "™", name: "trademark" },
        { glyph: "©", name: "copyright" },
        { glyph: "§", name: "section" },
        { glyph: "✓", name: "check tick" },
        { glyph: "✗", name: "cross fail" },
        { glyph: "★", name: "star filled" },
        { glyph: "☆", name: "star outline" },
        { glyph: "λ", name: "lambda" },
        { glyph: "π", name: "pi" },
        { glyph: "∞", name: "infinity" }
    ]

    readonly property var shown: {
        const q = root.filter.trim().toLowerCase();
        if (!q)
            return root.all.slice(0, 300);
        return root.all.filter(e => e.name.includes(q)).slice(0, 300);
    }

    function load(): void {
        if (!root.loaded)
            file.reload();
    }

    function copy(glyph: string): void {
        Quickshell.execDetached(["sh", "-c", `printf %s ${JSON.stringify(glyph)} | wl-copy`]);
    }

    FileView {
        id: file

        path: root.dataPath
        preload: false
        printErrors: false

        onLoaded: {
            const out = root.extras.slice();
            for (const line of text().split("\n")) {
                // "1F600 ; fully-qualified # 😀 grinning face"
                const m = line.match(/fully-qualified\s+#\s+(\S+)\s+(?:E\d+\.\d+\s+)?(.+)$/);
                if (m)
                    out.push({
                        glyph: m[1],
                        name: m[2].trim().toLowerCase()
                    });
            }
            root.all = out;
            root.loaded = true;
        }
    }
}
