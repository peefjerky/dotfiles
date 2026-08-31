pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fuzzy file search over $HOME using fd (already installed).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string query
    property var results: []
    property bool busy

    function search(q: string): void {
        root.query = q.trim();
        if (root.query.length < 2) {
            root.results = [];
            debounce.stop();
            return;
        }
        debounce.restart();
    }

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function reveal(path: string): void {
        Quickshell.execDetached(["xdg-open", path.slice(0, path.lastIndexOf("/")) || "/"]);
    }

    // Typing shouldn't spawn a filesystem walk per keystroke.
    Timer {
        id: debounce

        interval: 250
        onTriggered: {
            root.busy = true;
            proc.running = false;
            proc.running = true;
        }
    }

    Process {
        id: proc

        // --max-results caps the walk itself, so a broad query cannot run away.
        // Hidden and ignored files are skipped, which is what makes it usable.
        command: ["sh", "-c", `fd --type f --max-results 60 --absolute-path ${JSON.stringify(root.query)} ${JSON.stringify(root.home)} 2>/dev/null`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.results = text.split("\n").filter(l => l.length).map(p => ({
                            path: p,
                            name: p.slice(p.lastIndexOf("/") + 1),
                            dir: p.slice(0, p.lastIndexOf("/")).replace(root.home, "~")
                        }));
            }
        }
    }
}
