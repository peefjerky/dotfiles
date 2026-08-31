import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.components

// Empty states teach the interface rather than reporting that it is empty, so
// every view says what the tab is for and what to do next.
ColumnLayout {
    id: root

    required property string icon
    required property string title
    property string detail

    spacing: Tokens.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter

        text: root.icon
        color: Colours.palette.m3outlineVariant
        fontStyle: Tokens.font.icon.large
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        text: root.title
        font: Tokens.font.body.medium
        color: Colours.palette.m3onSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 380

        visible: root.detail.length > 0
        text: root.detail
        font: Tokens.font.body.small
        color: Colours.palette.m3outline
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
