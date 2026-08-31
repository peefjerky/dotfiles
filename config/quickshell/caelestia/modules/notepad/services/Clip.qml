pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, backed by the cliphist store caelestia already fills.
//
// `caelestia clipboard` pipes that same store through fuzzel, which is why it
// looks nothing like the shell and can only ever show `[[ binary data ... ]]` for
// an image. Reading cliphist directly lets the entries be real QML items, so
// images can show an actual thumbnail.
Singleton {
    id: root

    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/caelestia-notepad/clip`

    // [{ id, preview, image, w, h }]
    property var entries: []
    property bool loaded
    // Bumped when a decode pass finishes, so cached Image sources re-resolve.
    property real thumbsReady

    // Rendering the whole history is pointless -- anything past the most recent
    // few dozen is faster to re-copy than to scroll to.
    readonly property int limit: 60

    function wipe(): void {
        Quickshell.execDetached(["sh", "-c", `cliphist wipe; rm -f ${root.cacheDir}/*`]);
        root.entries = [];
    }

    function refresh(): void {
        list.running = false;
        list.running = true;
    }

    function copy(id: string): void {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${id} | wl-copy`]);
        // cliphist stores through wl-paste --watch, so the new entry only lands a
        // moment later. Re-read once it has, so the list reflects what was copied
        // instead of looking like nothing happened.
        settle.restart();
    }

    function remove(id: string): void {
        // cliphist delete wants the original list line on stdin, not an id.
        Quickshell.execDetached(["sh", "-c", `cliphist list | grep -m1 '^${id}\t' | cliphist delete`]);
        root.entries = root.entries.filter(e => e.id !== id);
    }

    // Path a thumbnail will live at once decoded. Decoding is the delegate's job,
    // so it only happens for rows actually scrolled into view.
    function thumbPath(id: string): string {
        return `${root.cacheDir}/${id}`;
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.cacheDir]
    }

    // Decode every image entry that isn't cached yet, in one pass. Simpler and
    // more predictable than a Process per delegate, and there are only ever a
    // handful of images in a history of mostly text.
    Process {
        id: thumbs

        command: ["sh", "-c", `mkdir -p ${root.cacheDir}; cliphist list | grep 'binary data' | while IFS="	" read -r id rest; do [ -s "${root.cacheDir}/$id" ] || cliphist decode "$id" > "${root.cacheDir}/$id"; done`]

        onExited: root.thumbsReady = Date.now()
    }

    Process {
        id: list

        running: true
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length).slice(0, root.limit).map(l => {
                    const tab = l.indexOf("\t");
                    const id = l.slice(0, tab);
                    const preview = l.slice(tab + 1);
                    const m = preview.match(/^\[\[\s*binary data .*?(\d+)x(\d+)\s*\]\]$/);
                    return {
                        id: id,
                        preview: preview,
                        image: !!m,
                        w: m ? parseInt(m[1]) : 0,
                        h: m ? parseInt(m[2]) : 0
                    };
                });
                root.loaded = true;
                thumbs.running = true;
            }
        }
    }
}
