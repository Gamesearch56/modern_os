import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

PopupWindow {
    id: root

    property Item anchorItem: null

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: Tokens.spacing.xxl * 10
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs + Tokens.spacing.sm * 2

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.rect.y: root.anchorItem ? root.anchorItem.height + Tokens.spacing.xs : 0
    anchor.rect.width: 1
    anchor.rect.height: 1

    Connections {
        target: Alarm
        function onDialogOpenChanged() {
            if (root.visible !== Alarm.dialogOpen)
                root.visible = Alarm.dialogOpen;
            if (root.visible)
                root.anchor.updateAnchor();
        }
    }

    onVisibleChanged: {
        if (Alarm.dialogOpen !== root.visible)
            Alarm.dialogOpen = root.visible;
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        context: Qt.ApplicationShortcut
        onActivated: Alarm.dialogOpen = false
    }

    MCard {
        anchors.fill: parent
        level: 1
        color: Colors.color.surface
        opacity: 1
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        padding: Tokens.spacing.sm

        RowLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MIconButton {
                iconName: "list-remove-symbolic"
                onClicked: Alarm.durationMin = Math.max(1, Alarm.durationMin - 1)
            }
            MTextField {
                Layout.fillWidth: true
                text: String(Alarm.durationMin)
                onTextEdited: Alarm.durationMin = Math.max(1, Number(text) || 1)
                onAccepted: Alarm.durationMin = Math.max(1, Number(text) || 1)
            }
            MIconButton {
                iconName: "list-add-symbolic"
                onClicked: Alarm.durationMin = Alarm.durationMin + 1
            }
            MButton {
                kind: "filled"
                key: "alarm.start"
                onClicked: Alarm.start(Alarm.durationMin)
            }
        }
    }

    Component.onCompleted: root.visible = Alarm.dialogOpen
}
