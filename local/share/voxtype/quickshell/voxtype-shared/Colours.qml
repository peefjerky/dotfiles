pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// Material 3 palette, read from the same file caelestia reads.
//
// ~/.local/state/caelestia/scheme.json is rewritten by matugen (through the
// caelestia CLI) every time the wallpaper or scheme changes. Watching it with
// FileView.watchChanges is the whole retheme mechanism -- there is nothing to
// restart and no IPC involved; the bindings below just re-evaluate.
//
// This is deliberately a copy of the *pattern* rather than an import of
// caelestia's own Colours singleton: that one lives in caelestia's `qs.services`
// namespace, which is private to its config and not reachable from here.
//
// Values in the JSON are bare 6-digit hex with no leading '#', hence the prefix
// on assignment. Keys are un-prefixed there ("surface"), and M3-prefixed here
// ("m3surface"), matching caelestia so copied components work unmodified.
Singleton {
    id: root

    readonly property bool light: mode === "light"
    property string mode: "dark"

    // Transparency follows caelestia's own setting, so enabling it there applies
    // here too. Read straight off Tokens rather than duplicated in this config --
    // there is one switch, and it is caelestia's.
    readonly property QtObject transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))
    }

    function getLuminance(c: color): real {
        if (c.r === 0 && c.g === 0 && c.b === 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    // Lifts a colour as it loses opacity, so translucent surfaces stay legible
    // instead of sinking into the wallpaper. Caelestia's formula, minus its
    // wallpaper-luminance term: that comes from its compiled image analyser, which
    // is not reachable from another config. The consequence is that surfaces are
    // tuned slightly darker over very bright wallpapers than caelestia's own.
    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        if (luminance === 0)
            return Qt.rgba(c.r, c.g, c.b, a);
        const offset = (!root.light || layer === 1 ? 1 : -layer / 2) * (root.light ? 0.2 : 0.3) * (1 - root.transparency.base);
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(Math.max(0, Math.min(1, c.r * scale)), Math.max(0, Math.min(1, c.g * scale)), Math.max(0, Math.min(1, c.b * scale)), a);
    }

    // layer 0 = the window's own backdrop, which takes the base alpha; anything
    // else is a raised container and takes the layers alpha.
    function layer(c: color, l: var): color {
        if (!root.transparency.enabled)
            return c;
        return l === 0 ? Qt.alpha(c, root.transparency.base) : root.alterColour(c, root.transparency.layers, l ?? 1);
    }

    // Blur behind the surface, matching caelestia's own menus.
    //
    // Sent the same way caelestia does it (services/Colours.qml reloadHyprRules):
    // two layer rules via `hyprctl eval`, because the Lua config provider rejects
    // `keyword layerrule`. ignore_alpha is the important half -- it tells Hyprland
    // to skip blurring anything more opaque than that threshold, so only the
    // translucent surface is blurred and not the solid content on top of it.
    //
    // Namespace matches OsdSurface.qml's WlrLayershell.namespace. Driven from here
    // so it follows caelestia's transparency toggle without a compositor reload.
    function reloadHyprRules(): void {
        const rule = ns => `hl.layer_rule({ match = { namespace = "voxtype-osd" }, ${ns} })`;
        Quickshell.execDetached(["sh", "-c", `hyprctl eval ${JSON.stringify(rule(`blur = ${root.transparency.enabled}`))}; hyprctl eval ${JSON.stringify(rule(`ignore_alpha = ${Math.max(0, root.transparency.base - 0.03)}`))}`]);
    }

    // Rate limiter, so dragging the transparency slider doesn't spawn a hyprctl pair
    // per frame. Caelestia's own (services/Colours.qml:97-104).
    property bool cooldownPending
    // Deliberately not initialised from transparency.base: as a binding it would stay
    // live until the first assignment below and always compare equal, and the order of
    // a binding update against the change handler that reads it isn't guaranteed.
    // Starting at 0 costs one delayed reload on the first change, same as caelestia.
    property real lastBase

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running)
            root.cooldownPending = true;
        else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    // Getting *less* transparent has to wait out the colour cross-fade. The surface
    // animates over expressiveSlowEffects (CAnim, see NotepadWindow.surfaceColour),
    // so applying the higher ignore_alpha immediately would lift the threshold above
    // the surface's current alpha mid-fade and the blur would drop out early. Going
    // more transparent has the opposite problem and must apply at once.
    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    Component.onCompleted: root.reloadHyprRules()

    Connections {
        target: root.transparency

        function onEnabledChanged(): void {
            if (root.transparency.enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }

        function onBaseChanged(): void {
            if (root.lastBase > root.transparency.base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBase = root.transparency.base;
        }
    }

    // Transparency-aware palette. Bind window and container surfaces to this;
    // foreground colours stay on `palette`.
    readonly property QtObject tPalette: QtObject {
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
    }

    readonly property QtObject palette: QtObject {
        property color m3background: "#050302"
        property color m3onBackground: "#f9e0da"
        property color m3surface: "#050302"
        property color m3surfaceContainerLowest: "#000000"
        property color m3surfaceContainerLow: "#080303"
        property color m3surfaceContainer: "#0c0504"
        property color m3surfaceContainerHigh: "#0e0706"
        property color m3surfaceContainerHighest: "#110907"
        property color m3onSurface: "#f9e0da"
        property color m3surfaceVariant: "#110907"
        property color m3onSurfaceVariant: "#bca6a1"
        property color m3outline: "#84716c"
        property color m3outlineVariant: "#554440"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3primary: "#ffb4a4"
        property color m3onPrimary: "#5f1600"
        property color m3primaryContainer: "#862200"
        property color m3onPrimaryContainer: "#ffdbd1"
        property color m3secondary: "#e7bdb3"
        property color m3onSecondary: "#442a22"
        property color m3tertiary: "#d8c58d"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
    }

    function load(data: string): void {
        const scheme = JSON.parse(data);
        root.mode = scheme.mode;

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const prop = `m3${name}`;
            // Only assign keys this palette actually declares. scheme.json carries
            // the full ~90-entry M3 set plus term0-15; the notepad uses a subset,
            // and assigning an undeclared name would be a silent no-op anyway.
            if (root.palette[prop] !== undefined)
                root.palette[prop] = `#${colour}`;
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }
}
