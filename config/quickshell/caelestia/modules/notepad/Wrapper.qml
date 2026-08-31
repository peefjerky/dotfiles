pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.notepad.services

// The notepad panel, built exactly like caelestia's own bottom-anchored panel.
//
// This used to be a standalone Quickshell config on its own Wayland layer surface
// above caelestia's. It rendered correctly but could never look right at the bottom
// edge: caelestia's border casts its MultiEffect shadow inward into the hole, and a
// separate translucent surface sitting on top of that shadow transmits ~15% of it as
// a dark band. Caelestia's own panels have no such band because they live inside the
// same flattened silhouette -- a merged blob has no internal edge, so no shadow is
// drawn at the seam. There is no way to reproduce that from another process.
//
// So the notepad is now a panel in caelestia's own tree, sharing its BlobGroup. That
// removes the band by construction, and gets real blob merging with the launcher,
// sidebar and popouts for free (see CAELESTIA-BLOBS.md in this directory).
//
// Structure is copied from modules/launcher/Wrapper.qml, which is the panel this one
// is geometrically identical to: bottom-anchored, horizontally centred, revealed by
// translating past the border on a single offsetScale.
Item {
    id: root

    required property ShellScreen screen
    required property var panels

    // NotepadState.open is what the user asked for; `fits` is whether the screen can
    // honour it right now. The buffer lives in Store, not here, so ducking out and
    // coming back loses nothing.
    readonly property bool shouldBeActive: NotepadState.open && fits

    // Size off the neighbours' *settled* sizes, never their in-flight animated ones.
    // implicitWidth/implicitHeight have Behaviors, and a Behavior chasing an
    // already-animating value trails a whole curve behind it and rubber-bands on
    // arrival. Caelestia's launcher sizes itself off the plain `screenState.dashboard`
    // bool and `nonAnimHeight` for exactly this reason (launcher/Wrapper.qml:19-25);
    // both panels then run the same Anim from the same frame and move as one.
    //
    // Position is the opposite case: `anchors.bottomMargin` has no Behavior, so it
    // reads the live animated offset and rides the launcher in lockstep. Caelestia
    // chains its right-edge panels the same way -- sidebar pushes session pushes osd
    // (Panels.qml:48, :84).
    readonly property real launcherOffset: panels.launcher.height * (1 - panels.launcher.offsetScale)
    readonly property real launcherHeight: panels.launcher.shouldBeActive ? panels.launcher.implicitHeight : 0
    readonly property real dashboardHeight: panels.dashboard.shouldBeActive ? panels.dashboard.nonAnimHeight : 0

    // Below this the panel is too short to be worth showing at all.
    readonly property real minHeight: 300

    // The band this panel gets: between the dashboard's bottom edge and the launcher's
    // top edge. `parent` is Panels, which is already inset to the border hole, so its
    // size IS the space available. The dashboard comes down from the top and would
    // otherwise draw straight over this panel's header.
    readonly property real availHeight: parent.height - Tokens.padding.large - launcherHeight - dashboardHeight

    // Dashboard (540) + launcher (448) already exceed the 976px hole on this display,
    // so with both open there is no arrangement where all three fit. Rather than
    // overlap someone -- or, as it did before, go negative and fling itself off the
    // bottom of the screen -- this panel ducks out and comes back when either closes.
    readonly property bool fits: availHeight >= minHeight

    // Neighbours that intrude from the sides.
    //
    // Left: bar popouts (wifi, bluetooth, battery) hang off the left border, centred on
    // whichever bar module is hovered, so a tall one reaches down into this panel.
    // Right: the sidebar column, or the utilities dock when the sidebar is closed --
    // with it open the dock is glued to the column at the same width, so the column
    // alone covers both.
    //
    // This panel is horizontally centred, so it is the *wider* side that constrains it,
    // and clearing that side costs twice its width -- shrinking by exactly its width
    // would only move the centre, not the edge.
    readonly property real maxWidth: {
        const left = panels.popouts.hasCurrent ? panels.popouts.nonAnimWidth : 0;
        const right = panels.sidebar.shouldBeActive ? panels.sidebar.implicitWidth : panels.utilities.shouldBeActive ? Tokens.sizes.utilities.width : 0;
        return parent.width - Tokens.padding.large * 2 - Math.max(left, right) * 2;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    // Closed, the panel rests *past* the border rather than flush with it: the SDF join
    // is not exact and a 0px gap still bulges the frame. The -5 is caelestia's, used by
    // every panel wrapper in the tree.
    //
    // launcherOffset is scaled by (1 - offsetScale) so it only applies while open.
    // Unscaled, a closed panel got pushed back up by roughly the launcher's height and
    // reappeared as a slab poking out of the launcher's top edge -- which looks exactly
    // like the launcher's own container having grown, but is this panel.
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale + launcherOffset * (1 - offsetScale)
    implicitWidth: Math.min(900, maxWidth)
    // Clamped at minHeight rather than 0: while ducking out, availHeight is negative,
    // and a negative height anchors the top *below* the bottom edge, which spills the
    // card off the screen instead of sliding it off.
    implicitHeight: Math.max(minHeight, Math.min(620, availHeight))
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    // Resizing to make room for a neighbour is a geometry change, so it gets a spatial
    // curve, same as every other panel movement in the shell.
    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Loader {
        id: content

        anchors.fill: parent

        active: root.shouldBeActive || root.visible

        sourceComponent: Card {
            id: card

            onRequestMode: i => {
                card.mode = i;
                if (i === 1)
                    Clip.refresh();
                else if (i === 5)
                    Projects.refresh();
                else if (i === 6)
                    Emoji.load();
            }

            Shortcut {
                sequence: "Escape"
                enabled: root.shouldBeActive
                onActivated: NotepadState.open = false
            }

            Shortcut {
                sequence: "Ctrl+E"
                enabled: root.shouldBeActive
                onActivated: card.rawMode = !card.rawMode
            }

            Shortcut {
                sequence: "Ctrl+S"
                enabled: root.shouldBeActive
                onActivated: card.save()
            }

            Shortcut {
                sequence: "Ctrl+D"
                enabled: root.shouldBeActive
                onActivated: {
                    card.requestMode(4);
                    card.focusDict(card.selection);
                }
            }

            // Instantiator, not Repeater: a Repeater delegate must be an Item, and a
            // Shortcut is not one -- it silently created nothing and logged "Delegate
            // must be of Item type", so Ctrl+1..7 never fired.
            Instantiator {
                model: 7

                Shortcut {
                    required property int index

                    sequence: `Ctrl+${index + 1}`
                    enabled: root.shouldBeActive
                    onActivated: card.requestMode(index)
                }
            }
        }
    }
}
