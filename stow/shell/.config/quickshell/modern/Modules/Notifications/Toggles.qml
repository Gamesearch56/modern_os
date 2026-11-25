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
            iconName: Network.wifiEnabled ? "network-wireless-symbolic" : "network-offline-symbolic"
            titleKey: "bar.network"
            checked: Network.wifiEnabled
            enabled: Network.wifiHardwareEnabled
            onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
        }
        MQuickTile {
            Layout.fillWidth: true
            iconName: Bluetooth.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            titleKey: "bar.bluetooth"
            checked: Bluetooth.powered
            enabled: Bluetooth.adapterReady
            onClicked: Bluetooth.setPowered(!Bluetooth.powered)
        }
        MQuickTile {
            Layout.fillWidth: true
            iconName: "notifications-disabled-symbolic"
            titleKey: "notifications.dnd"
            checked: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
        MQuickTile {
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

            AlarmPicker {}
        }
        MQuickTile {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            centerAlign: true
            iconName: "camera-photo-symbolic"
            titleKey: "screenshot.capture"
            onClicked: {
                Notifications.hide();
                if (Recording.active)
                    Recording.stop();
                else
                    Screenshot.pick("region");
            }
        }
    }
}
