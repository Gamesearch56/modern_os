// Horizontal strip of palette swatches. Colors are data from matugen
// dry-runs, not chrome tokens.
import QtQuick
import QtQuick.Layouts
import "../Commons"

RowLayout {
    id: root

    property var colors: []

    spacing: Tokens.spacing.xxs

    Repeater {
        model: root.colors

        Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xl
            radius: Tokens.radius.small
            color: String(modelData || Colors.color.surfaceVariant)
        }
    }
}
