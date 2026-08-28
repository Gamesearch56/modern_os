import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MChip {
            key: "bar.network"
            checked: Network.wifiEnabled
            onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
        }

        MChip {
            key: "bar.bluetooth"
            checked: Bluetooth.powered
            onClicked: Bluetooth.setPowered(!Bluetooth.powered)
        }

        MChip {
            key: "notifications.dnd"
            checked: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
    }

    MText {
        key: "bar.volume"
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }

    MSlider {
        Layout.fillWidth: true
        from: 0
        to: Config.audio.masterVolumeLimit ?? 100
        value: Audio.volume
        onMoved: (v) => Audio.setVolume(v)
    }

    MText {
        key: "quickSettings.brightness"
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }

    MSlider {
        Layout.fillWidth: true
        enabled: Brightness.available
        from: 1
        to: 100
        value: Brightness.percent
        onMoved: (v) => Brightness.setPercent(v)
    }
}
