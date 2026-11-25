// Filter chip. Selected is outlined (primary stroke) rather than filled
// grey, so it does not compete with nav pills.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string key: ""
    property var params: ({})
    property string value: ""
    property bool checked: false
    property bool enabled: true
    property bool interactive: true

    signal clicked()

    implicitWidth: row.implicitWidth + Tokens.spacing.lg * 2
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.sm
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled && root.interactive
    Accessible.role: root.interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.key.length > 0 ? I18n.t(root.key, root.params) : root.value
    Accessible.checkable: root.interactive
    Accessible.checked: root.checked
    Accessible.onPressAction: {
        if (root.interactive)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if (!root.interactive)
            return;
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

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.primary
        opacity: root.interactive ? Chrome.stateLayer(ma.containsMouse, ma.pressed) : 0
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MText {
            key: root.key
            params: root.params
            value: root.value
            styleName: "labelLarge"
            color: root.checked ? Colors.color.primary : Colors.color.onSurfaceVariant
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: true
        hoverEnabled: true
        acceptedButtons: root.interactive ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: {
            if (root.interactive)
                ring.markPointer();
        }
        onClicked: {
            if (root.interactive)
                root.clicked();
        }
    }

    MFocusRing {
        id: ring
        radius: Tokens.radius.full
    }
}
