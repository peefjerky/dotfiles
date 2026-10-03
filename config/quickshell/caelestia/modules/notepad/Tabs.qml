pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Navigation rail, inside the panel.
//
// It used to protrude from the panel edge as a second BlobRect in the shared
// group. That could never sit flush: where two blob shapes overlap their fields
// sum and the surface inflates outward, measured at ~10px, and no inset, overlap
// depth or corner radius removed it -- only the offsets moved. Inside the panel
// the problem does not exist, and a rail is the conventional answer for seven tabs
// anyway: it scales, and it does not compete with the header for the top edge.
//
// Separation is a surface-layer change plus a hairline, which is how a toolbar
// reads as a distinct region without drawing a box around itself.
Item {
    id: root

    required property int current

    signal selected(index: int)

    readonly property var tabs: [
        { icon: "description", name: "Note" },
        { icon: "content_paste", name: "Clipboard" },
        { icon: "palette", name: "Colours" },
        { icon: "search", name: "Files" },
        { icon: "book_2", name: "Dictionary" },
        { icon: "folder_code", name: "Projects" },
        { icon: "mood", name: "Emoji" }
    ]

    readonly property real slot: 52
    // Vertically centre the stack of tabs within the rail.
    readonly property real topInset: (height - tabs.length * slot) / 2

    implicitWidth: 64

    // The second neutral layer: a rail is a toolbar, not content.
    //
    // Inset rather than full-bleed, deliberately. Full-bleed meant a square rect
    // painted over the panel's rounded top-left corner and over its concave
    // bottom-left fillet -- and a Rectangle cannot reproduce a concave blob
    // fillet, so matching the panel's corners was never going to work. Inset, the
    // panel's own shape stays visible on every side and there is nothing to match.
    //
    // The surface-layer change alone separates it, so it needs no divider either.
    StyledRect {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        // Clear the border strip the panel sits flush against at the screen edge.
        anchors.bottomMargin: Tokens.spacing.small + Config.border.thickness

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
    }

    // One indicator that slides, so the change of tab is the motion rather than
    // two separate fades. Tab switches are the most frequent thing done here,
    // half of them from Ctrl+N, so this is the short standard curve with no
    // overshoot -- the expressive spatial curve it used to run bounced for half
    // a second on every switch.
    StyledRect {
        id: pill

        width: 44
        height: 44
        x: (root.implicitWidth - width) / 2
        y: root.topInset + root.current * root.slot + (root.slot - height) / 2

        radius: Tokens.rounding.full
        color: Colours.tPalette.m3primaryContainer

        Behavior on y {
            Anim {
                type: Anim.StandardSmall
            }
        }
    }

    Repeater {
        model: root.tabs

        Item {
            id: tab

            required property int index
            required property var modelData

            readonly property bool active: index === root.current

            x: (root.implicitWidth - width) / 2
            y: root.topInset + index * root.slot + (root.slot - height) / 2
            width: 44
            height: 44

            // Hover is the 8% state layer, on the same circle the pill fills, so
            // a hovered tab previews exactly where the indicator would land.
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    id: hover

                    onClicked: root.selected(tab.index)
                }
            }

            MaterialIcon {
                anchors.centerIn: parent

                text: tab.modelData.icon
                // Filled when active: the M3 rail's own active-state signal, so
                // the current tab reads even where the pill colour is subtle.
                fill: tab.active ? 1 : 0
                color: tab.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small

                Behavior on color {
                    CAnim {}
                }
            }

            Tip {
                anchors.left: parent.right
                anchors.leftMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter

                hovered: hover.containsMouse
                text: tab.modelData.name
                shortcut: `Ctrl+${tab.index + 1}`
                origin: Item.Left
            }
        }
    }
}
