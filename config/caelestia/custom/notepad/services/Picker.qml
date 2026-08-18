pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen colour picker, backed by hyprpicker (already installed, and already has
// a layer rule in ~/.config/hypr/hyprland/rules.lua).
Singleton {
    id: root

    readonly property string statePath: `${Quickshell.env("HOME")}/.cache/caelestia-notepad/colours.json`

    property var recent: []
    property bool picking

    function pick(): void {
        root.picking = true;
        proc.running = true;
    }

    function copy(hex: string): void {
        // JSON.stringify quotes it: an unquoted "#rrggbb" makes the shell treat
        // everything from the # as a comment, so nothing was ever copied.
        Quickshell.execDetached(["sh", "-c", `printf %s ${JSON.stringify(hex)} | wl-copy`]);
    }

    function clear(): void {
        root.recent = [];
        store.setText("[]");
    }

    Process {
        id: proc

        // -f hex prints the colour and exits; -r keeps it to just the value.
        command: ["hyprpicker", "-f", "hex", "-r"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.picking = false;
                const hex = text.trim();
                if (!hex.startsWith("#"))
                    return;
                // Most-recent-first, de-duplicated, capped.
                root.recent = [hex].concat(root.recent.filter(c => c !== hex)).slice(0, 24);
                store.setText(JSON.stringify(root.recent));
                root.copy(hex);
            }
        }

        onExited: root.picking = false
    }

    FileView {
        id: store

        path: root.statePath
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {
                root.recent = [];
            }
        }
    }
}
