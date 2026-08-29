import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.xxs

    readonly property string _remaining: {
        const s = Alarm.remainingSec;
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    MListItem {
        Layout.fillWidth: true
        iconName: "network-wireless-symbolic"
        titleKey: "bar.network"
        onClicked: {
            Notifications.hide();
            Settings.openAt("network", "");
        }
    }
    MListItem {
        Layout.fillWidth: true
        iconName: "bluetooth-symbolic"
        titleKey: "bar.bluetooth"
        onClicked: {
            Notifications.hide();
            Settings.openAt("bluetooth", "");
        }
    }
    MListItem {
        Layout.fillWidth: true
        iconName: "notifications-disabled-symbolic"
        titleKey: "notifications.dnd"
        onClicked: Notifications.toggleDnd()
        MSwitch {
            checked: Notifications.dnd
            onToggled: (v) => Notifications.dnd = v
        }
    }
    MListItem {
        Layout.fillWidth: true
        iconName: "alarm-symbolic"
        titleKey: Alarm.running ? "alarm.running" : "alarm.title"
        subtitleValue: Alarm.running ? _remaining : ""
        onClicked: {
            if (Alarm.running)
                Alarm.cancel();
            else
                Alarm.toggleDialog();
        }
    }

    RowLayout {
        visible: Alarm.dialogOpen
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MIconButton {
            iconName: "list-remove-symbolic"
            onClicked: Alarm.durationMin = Math.max(1, Alarm.durationMin - 1)
        }
        MTextField {
            Layout.fillWidth: true
            text: String(Alarm.durationMin)
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

    MListItem {
        Layout.fillWidth: true
        iconName: "camera-photo-symbolic"
        titleKey: "screenshot.capture"
        onClicked: Screenshot.pick("region")
    }
}
