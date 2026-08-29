import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MOverlay {
    id: root
    property var device: null
    open: root.device !== null
    titleValue: root.device ? (root.device.name || "") : ""
    cardHeight: Tokens.spacing.xxl * 8

    ColumnLayout {
        spacing: Tokens.spacing.md
        MButton {
            visible: root.device && !root.device.connected
            kind: "filled"
            key: "settings.bluetooth.connect"
            onClicked: {
                Bluetooth.connectDevice(root.device);
                root.closed();
            }
        }
        MButton {
            visible: root.device && root.device.connected
            kind: "tonal"
            key: "settings.bluetooth.disconnect"
            onClicked: {
                Bluetooth.disconnectDevice(root.device);
                root.closed();
            }
        }
        MButton {
            kind: "text"
            key: "settings.bluetooth.forget"
            onClicked: {
                Bluetooth.forgetDevice(root.device);
                root.closed();
            }
        }
    }
}
