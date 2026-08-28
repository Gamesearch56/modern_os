// Monospace combo chip for cheatsheet rows and the keyboard section.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property string value: ""

    radius: Tokens.radius.small
    color: Colors.color.surfaceContainerHighest
    implicitWidth: cap.implicitWidth + Tokens.spacing.sm * 2
    implicitHeight: cap.implicitHeight + Tokens.spacing.xs
    border.color: Colors.color.outlineVariant
    border.width: 1

    MText {
        id: cap
        anchors.centerIn: parent
        value: root.value
        styleName: "labelMedium"
        familyRole: "monospace"
    }
}
