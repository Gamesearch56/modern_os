// MD3 switch. Track filled primary when on; thumb travels with snappy spring.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool _pointerFocus: false

    signal toggled(bool value)

    implicitWidth: Tokens.spacing.xxl + Tokens.spacing.xl
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.sm
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggled(!root.checked)

    onActiveFocusChanged: {
        if (!root.activeFocus)
            root._pointerFocus = false;
    }

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
        border.width: root.checked ? 0 : 2

        Behavior on color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        id: thumb
        width: Tokens.icon.sm
        height: Tokens.icon.sm
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
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root._pointerFocus = true;
            root.forceActiveFocus();
            root.toggled(!root.checked);
        }
    }

    MFocusRing {
        radius: Tokens.radius.full
        active: root.activeFocus && !root._pointerFocus
    }
}
