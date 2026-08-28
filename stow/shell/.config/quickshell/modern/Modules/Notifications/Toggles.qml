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
            kind: Network.wifiEnabled ? "filled" : "tonal"
            key: "bar.network"
            iconName: "network-wireless"
            fillWidth: true
            onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
        }
        MButton {
            kind: Bluetooth.powered ? "filled" : "tonal"
            key: "bar.bluetooth"
            iconName: "bluetooth-active"
            fillWidth: true
            onClicked: Bluetooth.setPowered(!Bluetooth.powered)
        }
        MButton {
            kind: Notifications.dnd ? "filled" : "tonal"
            key: "notifications.dnd"
            iconName: "notifications-disabled"
            fillWidth: true
            onClicked: Notifications.toggleDnd()
        }
        MButton {
            kind: IdleInhibit.active ? "filled" : "tonal"
            key: "quickSettings.caffeine"
            iconName: "caffeine-cup-full"
            fillWidth: true
            onClicked: IdleInhibit.toggle()
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
