// Numeric notification counter. Hidden at 0; caps at 99+.
import QtQuick
import "../Commons"

Item {
    id: root

    property int count: 0

    readonly property string _label: root.count > 99 ? "99+" : String(root.count)

    visible: root.count > 0
    implicitHeight: Tokens.spacing.lg
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + Tokens.spacing.xs * 2)
    Accessible.role: Accessible.StaticText
    Accessible.name: root._label

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.error
    }

    MText {
        id: label
        anchors.centerIn: parent
        value: root._label
        styleName: "labelSmall"
        color: Colors.color.onError
    }
}
