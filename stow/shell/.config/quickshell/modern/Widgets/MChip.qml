// Filter chip. Selected is outlined (primary stroke) rather than filled
// grey, so it does not compete with nav pills.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string key: ""
    property var params: ({})
    property bool checked: false
    property bool enabled: true

    signal clicked()

    implicitWidth: row.implicitWidth + Tokens.spacing.lg * 2
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.sm
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key, root.params) : ""
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.checked ? "transparent" : Colors.color.surfaceContainerHigh
        border.color: root.checked ? Colors.color.primary : Colors.color.outlineVariant
        border.width: root.checked ? 2 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MText {
            key: root.key
            params: root.params
            styleName: "labelLarge"
            color: root.checked ? Colors.color.primary : Colors.color.onSurfaceVariant
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }

    MFocusRing {
        radius: Tokens.radius.full
    }
}
