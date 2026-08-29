import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: toggles
    Layout.fillWidth: true
    spacing: Tokens.spacing.sm

    readonly property string _remaining: {
        const s = Alarm.remainingSec;
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.xs
        rowSpacing: Tokens.spacing.xs

        MQuickTile {
            Layout.fillWidth: true
            iconName: "network-wireless-symbolic"
            titleKey: "bar.network"
            checked: Network.connected
            onClicked: {
                Notifications.hide();
                Settings.openAt("network", "");
            }
        }
        MQuickTile {
            Layout.fillWidth: true
            iconName: "bluetooth-symbolic"
            titleKey: "bar.bluetooth"
            checked: Bluetooth.powered
            onClicked: {
                Notifications.hide();
                Settings.openAt("bluetooth", "");
            }
        }
        MQuickTile {
            Layout.fillWidth: true
            iconName: Notifications.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
            titleKey: "notifications.dnd"
            checked: Notifications.dnd
            tintIcon: false
            onClicked: Notifications.toggleDnd()
        }
        MQuickTile {
            id: alarmTile
            Layout.fillWidth: true
            iconName: "alarm-symbolic"
            titleKey: "alarm.title"
            subtitleValue: Alarm.running ? toggles._remaining : ""
            checked: Alarm.running || Alarm.dialogOpen
            onClicked: {
                if (Alarm.running)
                    Alarm.cancel();
                else
                    Alarm.toggleDialog();
            }

            AlarmPicker {
                anchorItem: alarmTile
            }
        }
        MQuickTile {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            iconName: "camera-photo-symbolic"
            titleKey: "screenshot.capture"
            centerAlign: true
            onClicked: {
                Notifications.hide();
                Screenshot.pick("region");
            }
        }
    }
}
