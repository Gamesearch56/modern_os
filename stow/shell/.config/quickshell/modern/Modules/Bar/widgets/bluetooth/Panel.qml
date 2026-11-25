import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.sm

    MSectionHeader {
        key: "bar.bluetooth"
        styleName: "headlineSmall"
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.bluetoothPower"
        MSwitch {
            checked: Bluetooth.powered
            onToggled: (v) => Bluetooth.setPowered(v)
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: Bluetooth.sortedDevices
        delegate: MListItem {
            required property var modelData
            readonly property bool online: {
                void modelData.connected;
                void BluetoothAudio.nodeSig;
                return BluetoothAudio.linked(modelData);
            }
            width: ListView.view.width
            iconName: "bluetooth"
            titleValue: modelData.name || modelData.address || ""
            selected: online
            onClicked: {
                if (online)
                    Bluetooth.disconnectDevice(modelData);
                else
                    Bluetooth.connectDevice(modelData);
            }
            opacity: !online && BluetoothSignal.searched && Bluetooth.isRemembered(modelData)
                && !BluetoothSignal.inRange(modelData) ? Tokens.dimmedOpacity : 1
            titleAccessory: MTag {
                key: !online && Bluetooth.isRemembered(modelData) ? "settings.bluetooth.remembered" : ""
            }

            MSignal {
                level: online ? -1 : BluetoothSignal.level(modelData)
                label: I18n.t("settings.signal.bars", { n: level })
            }
        }
    }

    MButton {
        kind: "text"
        key: "settings.sections.network"
        fillWidth: true
        onClicked: Settings.openAt("network", "")
    }
}
