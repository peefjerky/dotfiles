// Material Symbols icon, matching caelestia's components/MaterialIcon.qml.
//
// Caelestia's own version imports qs.services for Colours, which is private to
// its config; this one reads the Colours singleton from this module instead.
// Icons are Material Symbols *names* ("mic"), not Nerd Font codepoints.

import QtQuick
import Caelestia.Config

Text {
    id: root

    property real fill: 0
    property int grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface
    font: Tokens.font.icon.size(fontStyle.pointSize).weight(fontStyle.weight).vaxes(fontStyle.variableAxes).fill(fill.toFixed(1)).grade(grade).build()
}
