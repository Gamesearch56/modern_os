import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.sm

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.sm
        rowSpacing: Tokens.spacing.sm

        MButton {
            kind: "tonal"
            key: "bar.network"
            iconName: "network-wireless"
            fillWidth: true
            onClicked: {
                Notifications.hide();
                Settings.openAt("network", "");
            }
        }
        MButton {
            kind: "tonal"
            key: "bar.bluetooth"
            iconName: "bluetooth-active"
            fillWidth: true
            onClicked: {
                Notifications.hide();
                Settings.openAt("bluetooth", "");
            }
        }
        MButton {
            kind: Notifications.dnd ? "filled" : "tonal"
            key: "notifications.dnd"
            iconName: "notifications-disabled"
            fillWidth: true
            onClicked: Notifications.toggleDnd()
        }
        MButton {
            kind: Alarm.running ? "filled" : "tonal"
            key: Alarm.running ? "alarm.running" : "alarm.title"
            iconName: "alarm-symbolic"
            fillWidth: true
            onClicked: {
                if (Alarm.running)
                    Alarm.cancel();
                else
                    Alarm.toggleDialog();
            }
        }
    }

    RowLayout {
        visible: Alarm.dialogOpen
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MIconButton {
            iconName: "list-remove"
            onClicked: Alarm.durationMin = Math.max(1, Alarm.durationMin - 1)
        }
        MTextField {
            Layout.fillWidth: true
            text: String(Alarm.durationMin)
            onAccepted: Alarm.durationMin = Math.max(1, Number(text) || 1)
        }
        MIconButton {
            iconName: "list-add"
            onClicked: Alarm.durationMin = Alarm.durationMin + 1
        }
        MButton {
            kind: "filled"
            key: "alarm.start"
            onClicked: Alarm.start(Alarm.durationMin)
        }
    }

    MButton {
        kind: "tonal"
        key: "screenshot.capture"
        iconName: "camera-photo"
        fillWidth: true
        onClicked: Screenshot.pick("region")
    }
}
