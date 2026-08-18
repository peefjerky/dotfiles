// Markdown notepad overlay for caelestia.
//
// Run with:  qs -p ~/.config/caelestia/custom/notepad
// Started by ~/.config/caelestia/custom/notepad.lua, toggled by SUPER+G
// (see ~/.config/caelestia/custom/keybinds.lua).
//
// This is a separate quickshell config on purpose. Caelestia's shell has no
// drop-in/plugin mechanism for user QML -- its `custom/` directory is Lua for
// Hyprland -- so extending it would mean editing /etc/xdg/quickshell/caelestia,
// which is package-owned and would be overwritten on update. A sibling config
// costs nothing and reads caelestia's own design tokens directly.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules
import qs.services

ShellRoot {
    id: root

    // Applies the blur/ignore_alpha layer rules at process start. Layer rules are
    // read when a surface maps, and Colours is otherwise only instantiated on the
    // first open -- which would leave that first reveal unblurred. On a QtObject
    // rather than on ShellRoot, which has no Component attached object.
    QtObject {
        Component.onCompleted: Colours.reloadHyprRules()
    }

    // Nothing is instantiated until first use, and the whole window is destroyed
    // again on close -- no idle cost for a panel that is shut most of the time.
    // The id is deliberately not `loader`: NotepadWindow declares a property of
    // that name, and inside the component the property shadows the outer id, so
    // `loader: loader` resolves to itself and QML reports a binding loop.
    LazyLoader {
        id: winLoader

        NotepadWindow {
            loader: winLoader
        }
    }

    function toggle(): void {
        if (!winLoader.active)
            // The window opens itself once constructed, so the reveal animates from
            // its closed state rather than snapping into place.
            winLoader.active = true;
        else if (winLoader.item)
            // Also covers pressing the key again mid-close: re-targeting the same
            // Behavior instead of fighting it.
            winLoader.item.toggle();
    }

    GlobalShortcut {
        appid: "notepad"
        name: "toggle"
        description: "Toggle the markdown notepad"

        onPressed: root.toggle()
    }

    // Scriptable equivalents, for the CLI and for testing without a keypress:
    //   qs -p ~/.config/caelestia/custom/notepad ipc call notepad save
    IpcHandler {
        target: "notepad"

        function toggle(): void {
            root.toggle();
        }

        // Works whether or not the overlay is open -- the buffer lives in Store,
        // which outlives the window.
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
