// MD3 switch. Track filled primary when on; thumb travels with snappy spring.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool compact: false
    property string nameKey: ""

    signal toggled(bool value)

    implicitWidth: root.compact ? Tokens.spacing.xxl + Tokens.spacing.xs : Tokens.spacing.xxl + Tokens.spacing.xl
    implicitHeight: root.compact ? Tokens.spacing.lg : Tokens.spacing.xl + Tokens.spacing.sm
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.nameKey.length > 0 ? I18n.t(root.nameKey) : ""
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggled(!root.checked)

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.toggled(!root.checked);
            event.accepted = true;
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.checked ? Colors.color.primary : Colors.color.surfaceVariant
        border.color: root.checked ? Colors.color.primary : Colors.color.outline
        border.width: root.checked ? 0 : (root.compact ? Tokens.stroke.hairline : Tokens.stroke.focus)

        Behavior on color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        id: thumb
        width: root.compact ? Tokens.spacing.md : Tokens.icon.sm
        height: width
        radius: Tokens.radius.full
        color: root.checked ? Colors.color.onPrimary : Colors.color.outline
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked
           ? parent.width - width - (root.compact ? Tokens.spacing.xxs : Tokens.spacing.xs)
           : (root.compact ? Tokens.spacing.xxs : Tokens.spacing.xs)

        Behavior on x {
            SpringAnimation {
                spring: Motion.springSnappy.spring
                damping: Motion.springSnappy.damping
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            ring.markPointer();
            root.forceActiveFocus();
            root.toggled(!root.checked);
        }
    }

    MFocusRing {
        id: ring
        radius: Tokens.radius.full
    }
}
