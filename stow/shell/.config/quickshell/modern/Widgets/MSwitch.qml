// MD3 switch. Stateless: `checked` in, `toggled(bool)` out. Track and
// thumb colors come from Tokens/Colors; travel uses the snappy spring.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: Tokens.spacing.xxl + Tokens.spacing.lg
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.checked ? Colors.color.primary : Colors.color.surfaceVariant
        border.color: root.checked ? Colors.color.primary : Colors.color.outline
        border.width: 2

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        id: thumb
        width: Tokens.spacing.lg
        height: Tokens.spacing.lg
        radius: Tokens.radius.full
        color: root.checked ? Colors.color.onPrimary : Colors.color.outline
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - Tokens.spacing.xs : Tokens.spacing.xs

        Behavior on x {
            SpringAnimation {
                spring: Motion.springSnappy.spring
                damping: Motion.springSnappy.damping
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
