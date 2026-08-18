pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.services

PanelWindow {
    id: root

    required property LazyLoader loader

    // Starts closed and is opened from Component.onCompleted, which is what gives
    // the reveal something to animate. A Behavior only runs on a *change*: with
    // `wantOpen: true` as the initial value the binding below evaluated straight to
    // 0, and since LazyLoader builds a fresh window on every open, the panel was
    // born already at rest and simply appeared. The only thing moving was the
    // scrim fading over it, which is why opening read as "fading into existence".
    property bool wantOpen

    // Distinguishes "not open yet" from "closing". Without it the teardown below
    // would fire on the very first frame, when offsetScale is legitimately 1.
    property bool closing

    // 0 = fully open, 1 = fully closed. One animated value drives the panel's
    // position, the scrim and the teardown -- caelestia's own panels are built
    // exactly this way (see modules/osd/Wrapper.qml).
    property real offsetScale: wantOpen ? 0 : 1

    Component.onCompleted: root.open()

    readonly property real borderThickness: contentItem.Config.border.thickness
    readonly property real borderRounding: contentItem.Config.border.rounding

    // Cross-faded rather than assigned, so a matugen retheme with the panel open
    // recolours in step with caelestia's own panels instead of snapping a frame
    // ahead of them (ContentWindow.qml:45, :84-86).
    property color surfaceColour: Colours.tPalette.m3surface

    // Width of caelestia's bar, i.e. where its border frame's inner hole starts on
    // the left. It is a live layout value inside caelestia's own process and not
    // reachable from this one, so it is measured rather than read: scanning a
    // screenshot row, the bar's m3surface body ends and wallpaper begins at x=95
    // physical, which at scale 1.6 is ~60 logical.
    //
    // Re-measure if the bar ever changes width:
    //   grim /tmp/s.png && python3 -c "from PIL import Image; import numpy as np; \
    //     a=np.array(Image.open('/tmp/s.png').convert('RGB')); print(a[400][:140])"
    // and find the x where the near-black bar colour gives way to content.
    readonly property real barWidth: 60

    readonly property real panelWidth: 900
    readonly property real panelHeight: 620

    function open(): void {
        root.closing = false;
        root.wantOpen = true;
    }

    function close(): void {
        root.closing = true;
        root.wantOpen = false;
    }

    // Refresh on entry rather than polling: the clipboard only needs re-reading
    // when it is about to be looked at.
    function setMode(i: int): void {
        card.mode = i;
        if (i === 1)
            Clip.refresh();
        else if (i === 5)
            Projects.refresh();
        else if (i === 6)
            Emoji.load();
    }

    function toggle(): void {
        if (root.wantOpen)
            root.close();
        else
            root.open();
    }


    color: "transparent"

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    WlrLayershell.namespace: "notepad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Exclusive: a text editor has to receive every key the moment it opens, without
    // needing a click first. The cost is that while the notepad is open, keys go to it
    // rather than to a caelestia panel opened underneath — caelestia's own panels use
    // OnDemand plus a HyprlandFocusGrab, and a grab is exactly what must NOT be added
    // here (it would take the pointer back and undo the mask below).
    //
    // If typing into caelestia's launcher while the notepad is open turns out to
    // matter more than typing into the notepad without clicking it, the fix is this
    // one word: Exclusive -> OnDemand.
    WlrLayershell.keyboardFocus: wantOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Input is restricted to the panel itself, never to the whole surface.
    //
    // This is a fullscreen layer surface one level ABOVE caelestia's, so masking it
    // fullscreen swallowed every click on the desktop and on caelestia's own panels:
    // clicking the launcher, the sidebar or a bar popout while the notepad was open
    // hit the notepad's backdrop instead, which both ate the click and closed the
    // notepad. Masking to the panel rect lets everything outside fall straight
    // through, so caelestia stays fully usable underneath.
    //
    // Same technique caelestia uses on its own drawers window (`mask: regions`,
    // ContentWindow.qml:73) — it masks to its chrome so bare desktop reaches clients.
    //
    // The region runs down to the bottom border rather than stopping at the panel's
    // own edge, so the fillet where the two meet is clickable and there is no dead
    // strip along the base.
    mask: hole.visible ? panelRegion : emptyRegion

    Region {
        id: emptyRegion
    }

    Region {
        id: panelRegion

        x: hole.x + card.x
        y: hole.y + card.y
        width: card.width
        height: hole.height - card.y
    }

    // The single Behavior for the whole reveal. Plain `Anim {}` is caelestia's
    // default -- DefaultSpatial, 500ms on the expressiveDefaultSpatial curve --
    // which is what its bar popouts (wifi, bluetooth, tray menus) use, and one
    // Behavior serves both directions there rather than a faster close.
    Behavior on offsetScale {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    onOffsetScaleChanged: {
        if (closing && offsetScale >= 0.999)
            loader.active = false;
    }

    // No dim, and no backdrop MouseArea. Caelestia only scrims for its session menu
    // and detached popouts (ContentWindow: `opacity: ... ? 0.5 : 0`); its launcher,
    // dashboard and popouts darken nothing and grab nothing.
    //
    // Click-outside-to-dismiss is deliberately gone: it is the same thing as
    // swallowing every click meant for caelestia, and it cannot be had while the
    // notepad coexists with the rest of the shell. Escape and SUPER+G both still
    // close it, and neither depends on owning the pointer.

    // The hole in caelestia's border -- the same rect caelestia's own Panels.qml
    // occupies (`anchors.margins: borderThickness; anchors.leftMargin:
    // bar.implicitWidth`). Everything the notepad draws lives inside it, so this
    // surface can never paint over caelestia's border. That matters: the border is
    // already drawn at the transparency alpha one layer below us, and a second
    // translucent pass over it composites to 1-(1-a)^2 -- 0.98 at a=0.85 -- which
    // is a visibly darker ring.
    //
    // The clip is also what lets the frame below exist at all: its visible ring
    // falls entirely outside these bounds and is cropped, leaving only its
    // contribution to the shared distance field.
    Item {
        id: hole

        anchors.fill: parent
        anchors.margins: root.borderThickness
        anchors.leftMargin: root.barWidth
        clip: true

        visible: root.offsetScale < 1

        // Only the blob backgrounds are faded, never the content. Alpha has to be
        // applied as item opacity because the SDF renderer draws its fill opaque
        // and ignores the colour's alpha -- which is exactly how caelestia does it
        // (ContentWindow: `opacity: root.surfaceColour.a`), and why its panels go
        // translucent while text on them stays solid.
        Item {
            anchors.fill: parent
            opacity: root.surfaceColour.a

            // Flattens the frame and the panel into one texture before the opacity
            // is applied. The shader only guarantees one-writer-per-pixel *outside*
            // the blend zone (`if (owner != myIndex && mergedSdf > smoothFactor)
            // discard`) -- inside a fillet every overlapping shape draws, so without
            // this each would paint at 0.85 and the overlap would composite to 0.98.
            // Caelestia sets the same flag on its own blob layer for the same reason
            // (ContentWindow.qml:152).
            layer.enabled: true

            BlobGroup {
                id: blobGroup

                // BlobGroup is a plain QObject, so it sits outside the item tree and
                // never inherits the attached screen the window sets on contentItem.
                Tokens.screen: root.screen.name
                Config.screen: root.screen.name

                color: root.surfaceColour
                smoothing: Config.border.smoothing
            }

            // A replica of caelestia's screen border, in this config's own blob
            // group. It is never seen -- the clip above crops its whole ring -- but
            // the shader gives an inverted rect two terms that a plain rect does not
            // get, and both are what make a panel look like it grows *out of* the
            // border rather than resting against it:
            //
            //   dInner -= sinkValue    the frame's inner edge is eaten outward by
            //                          exactly how far the panel penetrates it, so
            //                          smin() welds the two into one concave fillet
            //   d *= 1 + prox * 3      a rect's own field is steepened up to 4x near
            //                          the frame, which keeps that fillet tight
            //
            // Without the second term the fillet balloons and snaps into place as the
            // panel decelerates. That was the bouncy bottom-left corner; a stand-in
            // BlobRect strip could not fix it because neither term fires against one.
            //
            // Geometry is caelestia's verbatim (ContentWindow.qml:166-175) except that
            // its inverted rect fills the whole window while this one fills the hole,
            // so every border* is just the inflation. The -50 is load-bearing rather
            // than cosmetic: kFrame = clamp(min(smoothing, minThick - 1), 1, smoothing)
            // reads the *whole* frame thickness, so the frame is inflated well past
            // smoothing to keep kFrame == smoothing.
            BlobInvertedRect {
                anchors.fill: parent
                anchors.margins: -50

                group: blobGroup
                radius: root.borderRounding

                borderLeft: -anchors.margins
                borderRight: -anchors.margins
                borderTop: -anchors.margins
                borderBottom: -anchors.margins
            }

            // The panel translates up from below the bottom edge at a FIXED size.
            //
            // It used to animate its height instead, mirroring how the wifi popout's
            // ClipWrapper animates its width. That was wrong here for two reasons.
            // Visually it reads as the panel scaling into existence rather than
            // arriving. Worse, the expressive spatial curves overshoot by design
            // (control points with y > 1), and an overshooting *size* clamps at zero
            // and rebounds -- measured frame by frame on close, the height went
            // 120 -> 8 -> 62 -> 0 -> 177 -> 34 before settling, which is the bottom
            // edge visibly pulsing upward after the panel had gone.
            //
            // Overshoot on a *position* is exactly what makes caelestia's panels feel
            // springy, and it has nothing to clamp against, so translation gets the
            // bounce for free and loses the artifact.
            //
            // Geometrically this is caelestia's launcher: bottom-anchored inside the
            // hole, centred, same PanelBg radius, same 0.1 deform. So it carries the
            // launcher's numbers, including the -5 -- panels rest *past* the border,
            // never flush with it, because the SDF join is not exact and a 0px gap
            // still bulges the frame while closed (launcher/Wrapper.qml:35).
            BlobRect {
                id: panelBlob

                group: blobGroup

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: (-implicitHeight - 5) * root.offsetScale

                implicitWidth: root.panelWidth
                implicitHeight: root.panelHeight

                // All four corners keep the full radius, as caelestia's launcher does.
                // Squaring the bottom pair by hand is unnecessary once the frame is
                // real -- the sink term flattens the join itself.
                radius: Tokens.rounding.extraLarge

                deformScale: (0.1 * Config.appearance.deformScale) / 10000
            }
        }

        // Content rides the panel exactly, so the whole thing moves as one finished
        // object rather than being revealed in place. Deliberately a sibling of the
        // faded Item above, never a child of it, so the surface goes translucent
        // and the text on it does not.
        Card {
            id: card

            onRequestMode: i => root.setMode(i)

            x: panelBlob.x
            y: panelBlob.y
            width: panelBlob.width
            height: panelBlob.height

            // Warped by the blob's own deformation matrix so the text flexes with
            // the surface instead of sliding across a rubbery background -- how
            // caelestia glues panel contents to their blobs.
            transform: Matrix4x4 {
                matrix: panelBlob.deformMatrix
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Shortcut {
        sequence: "Ctrl+E"
            onActivated: card.rawMode = !card.rawMode
    }

    Shortcut {
        sequence: "Ctrl+1"
            onActivated: root.setMode(0)
    }

    Shortcut {
        sequence: "Ctrl+2"
            onActivated: root.setMode(1)
    }

    Shortcut {
        sequence: "Ctrl+3"
            onActivated: root.setMode(2)
    }

    Shortcut {
        sequence: "Ctrl+4"
            onActivated: root.setMode(3)
    }

    Shortcut {
        sequence: "Ctrl+5"
            onActivated: root.setMode(4)
    }

    Shortcut {
        sequence: "Ctrl+6"
            onActivated: root.setMode(5)
    }

    Shortcut {
        sequence: "Ctrl+7"
            onActivated: root.setMode(6)
    }

    Shortcut {
        sequence: "Ctrl+D"
            onActivated: {
                root.setMode(4);
                card.focusDict(card.selection);
            }
    }

    Shortcut {
        sequence: "Ctrl+S"
            onActivated: card.save()
    }
}
