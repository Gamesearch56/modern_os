import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    property var devices: []
    property string emptyKey: ""
    property string emptyIcon: "bluetooth"
    property string scanningKey: ""
    property bool scanning: false

    signal deviceClicked(var device)

    readonly property bool _empty: root.emptyKey.length > 0 && root.devices.length === 0
    readonly property string _emptyTitle: root.scanning && root.scanningKey.length > 0 ? root.scanningKey : root.emptyKey

    spacing: Tokens.spacing.md

    MLinearProgress {
        visible: root.scanning && root.devices.length > 0
        Layout.fillWidth: true
        indeterminate: true
    }

    Repeater {
        model: root.devices.length
        MListItem {
            required property int index
            readonly property var dev: root.devices[index]
            readonly property string label: Bluetooth.deviceLabel(dev)
            readonly property string address: dev && dev.address ? String(dev.address) : ""
            readonly property bool showAddress: address.length > 0 && address !== label
            readonly property bool remembered: {
                void dev?.paired;
                void dev?.bonded;
                void dev?.trusted;
                void BluetoothLink.savedGen;
                return Bluetooth.isRemembered(dev);
            }
            readonly property bool online: {
                void dev?.connected;
                void BluetoothAudio.nodeSig;
                return BluetoothAudio.linked(dev);
            }
            readonly property bool inRange: BluetoothSignal.inRange(dev)
            readonly property int bars: BluetoothSignal.level(dev)
            // Before the first search ends, absence means nothing yet.
            readonly property bool away: remembered && !online && !inRange && BluetoothSignal.searched

            Layout.fillWidth: true
            opacity: away ? Tokens.dimmedOpacity : 1
            iconName: Bluetooth.deviceIcon(dev)
            preferSymbolic: false
            tintIcon: false
            titleValue: label
            subtitleValue: showAddress ? address : ""
            onClicked: root.deviceClicked(dev)
            titleAccessory: MTag {
                key: remembered && !online ? "settings.bluetooth.remembered" : ""
            }

            MSignal {
                level: online ? -1 : bars
                label: I18n.t("settings.signal.bars", { n: bars })
            }
        }
    }

    Item {
        visible: root._empty
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4

        MEmptyState {
            anchors.fill: parent
            iconName: root.emptyIcon
            titleKey: root._emptyTitle
        }

        MLinearProgress {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: root.scanning
            indeterminate: true
        }
    }
}
