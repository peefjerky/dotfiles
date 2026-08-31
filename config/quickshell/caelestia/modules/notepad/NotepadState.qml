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

    function toggle(): void {
        root.open = !root.open;
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
