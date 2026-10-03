import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notepad.services

// Transient confirmation. For export it is driven by Store's signals rather than
// by the click, because FileView writes are asynchronous -- reporting success on
// the click would be reporting it before the file exists. Everything else (a copy,
// mostly) arrives through NotepadState.toast.
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
        target: NotepadState

        function onToast(message: string): void {
            root.failed = false;
            root.message = message;
            root.shown = 1;
            hideTimer.restart();
        }
    }

    Connections {
        target: Store

        function onExported(path: string): void {
            root.failed = false;
            root.message = `Exported to ${path.replace(Store.home, "~")}`;
            root.shown = 1;
            hideTimer.restart();
        }

        function onExportFailed(reason: string): void {
            root.failed = true;
            root.message = `Export failed: ${reason}`;
            root.shown = 1;
            hideTimer.restart();
        }
    }
}
