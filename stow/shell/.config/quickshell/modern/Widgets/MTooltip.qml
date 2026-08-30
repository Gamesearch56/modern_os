// Hover tooltip. Delay comes from Motion.medium so it never uses a
// literal millisecond value. `key` is the I18n path for the label.
import QtQuick
import "../Commons"

Item {
    id: root

    property string key: ""
    property var params: ({})
    property bool active: false

    visible: root.active
    z: 50
    implicitWidth: label.implicitWidth + Tokens.spacing.md * 2
    implicitHeight: label.implicitHeight + Tokens.spacing.sm * 2
    opacity: root.active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.shortMs
            easing.bezierCurve: Motion.easingStandard
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Colors.color.inverseSurface
    }

    MText {
        id: label
        anchors.centerIn: parent
        key: root.key
        params: root.params
        styleName: "labelSmall"
        color: Colors.color.inverseOnSurface
    }
}
