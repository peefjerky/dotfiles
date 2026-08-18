import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Transient confirmation for the Save button. Driven by Store's signals rather
// than by the click, because FileView writes are asynchronous -- reporting success
// on the click would be reporting it before the file exists.
StyledRect {
    id: root

    property string message
    property bool failed
    property real shown

    implicitWidth: label.implicitWidth + Tokens.padding.large * 2
    implicitHeight: label.implicitHeight + Tokens.padding.medium * 2

    radius: Tokens.rounding.full
    color: failed ? Colours.palette.m3error : Colours.palette.m3primaryContainer

    opacity: shown
    visible: shown > 0
    scale: 0.92 + shown * 0.08

    Behavior on shown {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    StyledText {
        id: label

        anchors.centerIn: parent

        text: root.message
        font: Tokens.font.label.medium
        color: root.failed ? Colours.palette.m3onError : Colours.palette.m3onPrimaryContainer
    }

    Timer {
        id: hideTimer

        interval: 2400
        onTriggered: root.shown = 0
    }

    Connections {
        target: Store

        function onExported(path: string): void {
            root.failed = false;
            root.message = `Saved to ${path.replace(Store.home, "~")}`;
            root.shown = 1;
            hideTimer.restart();
        }

        function onExportFailed(reason: string): void {
            root.failed = true;
            root.message = `Save failed: ${reason}`;
            root.shown = 1;
            hideTimer.restart();
        }
    }
}
