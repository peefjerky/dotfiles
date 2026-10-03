pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.notepad.services

// Open/closed state for the notepad panel, plus the bind that drives it.
//
// Caelestia keeps per-panel state on `ScreenState` (launcher, session, dashboard,
// sidebar, bar), but that type is compiled into Caelestia.Components and cannot be
// extended from QML, so the notepad carries its own. The practical difference is
// that this is global rather than per-screen: the notepad opens on whichever screen
// its Panels instance is on, and on a multi-monitor setup it would open on all of
// them. Fine for one display; if that ever changes, the fix is a
// `property var openOn` keyed by screen name rather than a bool.
//
// The shortcut lives here rather than in Panels.qml because Panels is instantiated
// once per screen and a GlobalShortcut must be registered exactly once.
Singleton {
    id: root

    property bool open

    // The view, kept here rather than on the Card so it survives the panel's
    // Loader teardown: reopening lands where you left off, which for a scratch
    // tool is the point. 0 note, 1 clipboard, 2 colours, 3 files, 4 dictionary,
    // 5 projects, 6 emoji -- the Ctrl+1..7 order.
    property int mode
    property bool rawMode

    // A word waiting for the dictionary tab. Card consumes it, either at once if
    // the panel is up or when it next loads; empty means nothing pending.
    property string lookupWord
    signal lookupRequested

    // Tooltips show instantly until this time (see Tip.qml).
    property real tipWarmUntil

    readonly property var modes: ["note", "clipboard", "colours", "files", "dictionary", "projects", "emoji"]

    // One-line confirmations for actions with no visible result of their own
    // (copying, mostly). Shown by SaveToast.
    signal toast(message: string)

    function toggle(): void {
        root.open = !root.open;
    }

    // Open the dictionary tab on `word`. Trimmed to the word itself: a double-
    // click selection drags in surrounding punctuation, and a drag across a line
    // break brings the newline. An empty word still opens the tab, search focused.
    function define(word: string): void {
        // An explicit punctuation set: Qt's JS engine silently ignores \p{L}.
        const edge = /^[\s"'“”‘’«»„.,;:!?¡¿()\[\]{}<>…—–\-*_`~|\/\\]+|[\s"'“”‘’«»„.,;:!?¡¿()\[\]{}<>…—–\-*_`~|\/\\]+$/g;
        root.lookupWord = word.replace(/\s+/g, " ").replace(edge, "").slice(0, 64);
        root.mode = 4;
        root.open = true;
        root.lookupRequested();
    }

    // Highlighting text anywhere sets the Wayland primary selection, so "the
    // word under your selection" is just that -- no copy step, the clipboard is
    // left alone. `-t text` skips image selections; no selection exits non-zero
    // and lands here as an empty string, which still opens the tab.
    Process {
        id: readSelection

        command: ["wl-paste", "--primary", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: root.define(text)
        }
    }

    GlobalShortcut {
        appid: "notepad"
        name: "define"
        description: "Look up the highlighted word in the dictionary"

        onPressed: readSelection.running = true
    }

    GlobalShortcut {
        appid: "notepad"
        name: "toggle"
        description: "Toggle the markdown notepad"

        onPressed: root.toggle()
    }

    // Scriptable equivalents, for the CLI and for testing without a keypress:
    //   qs -c caelestia ipc call notepad save
    IpcHandler {
        target: "notepad"

        function toggle(): void {
            root.toggle();
        }

        // Explicit setters, so a script never has to guess the current state.
        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        function isOpen(): string {
            return root.open ? "true" : "false";
        }

        // By name or by its Ctrl+N number: `mode clipboard`, `mode 2`.
        function mode(name: string): string {
            const n = /^[1-7]$/.test(name) ? parseInt(name) - 1 : root.modes.indexOf(name);
            if (n < 0)
                return `unknown mode, expected 1-7 or one of: ${root.modes.join(", ")}`;
            root.mode = n;
            return root.modes[n];
        }

        function raw(on: bool): void {
            root.rawMode = on;
        }

        function define(word: string): void {
            root.define(word);
        }

        // Works whether or not the panel is open -- the buffer lives in Store,
        // which outlives the panel.
        function save(): void {
            Store.exportSnapshot();
        }

        function get(): string {
            return Store.content;
        }

        function set(text: string): void {
            Store.content = text;
        }
    }
}
