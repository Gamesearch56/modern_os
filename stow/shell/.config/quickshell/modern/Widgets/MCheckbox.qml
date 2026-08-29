// Unchecked / checked / disabled. `toggled(bool)` on click.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: Tokens.spacing.lg + Tokens.spacing.xs
    implicitHeight: Tokens.spacing.lg + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.CheckBox
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
        anchors.fill: parent
        radius: Tokens.radius.small / 2
        color: root.checked ? Colors.color.primary : "transparent"
        border.color: root.checked ? Colors.color.primary : Colors.color.outline
        border.width: 2

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }

        MIcon {
            visible: root.checked
            anchors.centerIn: parent
            name: "object-select-symbolic"
            size: Tokens.spacing.md
            color: Colors.color.onPrimary
            tint: true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggled(!root.checked);
        }
    }

    MFocusRing {
        radius: Tokens.radius.small / 2
    }
}
