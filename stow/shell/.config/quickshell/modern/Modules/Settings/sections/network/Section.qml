import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    property var pendingNet: null
    readonly property bool passwordOpen: root.pendingNet !== null

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.wifi"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                enabled: Network.wifiHardwareEnabled
                checked: Network.wifiEnabled
                onToggled: (v) => Network.setWifiEnabled(v)
            }
        }
        MHint {
            key: Network.wifiHardwareEnabled ? "settings.hints.wifi" : "settings.hints.wifiHardware"
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MIcon {
            name: "network-wired"
            size: Tokens.icon.md
        }
        ColumnLayout {
            spacing: Tokens.spacing.xxs
            Layout.fillWidth: true
            MText {
                key: "settings.fields.ethernet"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MText {
                visible: Network.wiredAddress.length > 0
                value: Network.wiredAddress
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }
        MText {
            key: Network.wiredConnected ? "settings.network.ethernetOn" : "settings.network.ethernetOff"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
        }
    }

    WifiList {
        Layout.fillWidth: true
        onRequestPassword: (n) => root.pendingNet = n
    }

    SpeedPanel {
        Layout.fillWidth: true
    }
}
