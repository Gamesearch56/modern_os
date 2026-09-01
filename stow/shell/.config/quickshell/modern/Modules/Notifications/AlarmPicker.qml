// Duration picker under the alarm tile. A nested PopupWindow would
// steal the control-panel focus grab and close the whole overlay.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    elevation: 2
    implicitWidth: Tokens.spacing.xxl * 11
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    Connections {
        target: Alarm
        function onDialogOpenChanged() {
            if (root.open !== Alarm.dialogOpen)
                root.open = Alarm.dialogOpen;
        }
    }

    onOpenChanged: {
        if (Alarm.dialogOpen !== root.open)
            Alarm.dialogOpen = root.open;
        if (root.open)
            Qt.callLater(() => minutesField.editor.forceActiveFocus());
    }

    Component.onCompleted: root.open = Alarm.dialogOpen
    Component.onDestruction: {
        if (Alarm.dialogOpen)
            Alarm.dialogOpen = false;
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.sm

        MText {
            key: "alarm.minutesHint"
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MIconButton {
                iconName: "list-remove-symbolic"
                onClicked: Alarm.durationMin = Math.max(1, Alarm.durationMin - 1)
            }
            MTextField {
                id: minutesField
                Layout.fillWidth: true
                text: String(Alarm.durationMin)
                onTextEdited: Alarm.durationMin = Math.max(1, Number(text) || 1)
                onAccepted: Alarm.start(Alarm.durationMin)
            }
            MIconButton {
                iconName: "list-add-symbolic"
                onClicked: Alarm.durationMin = Alarm.durationMin + 1
            }
        }

        MButton {
            kind: "filled"
            key: "alarm.start"
            fillWidth: true
            Layout.fillWidth: true
            onClicked: Alarm.start(Alarm.durationMin)
        }
    }
}
