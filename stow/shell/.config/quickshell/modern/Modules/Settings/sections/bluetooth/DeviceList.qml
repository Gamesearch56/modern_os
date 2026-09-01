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

    signal deviceClicked(var device)

    spacing: Tokens.spacing.md

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
                return !!(dev && (dev.paired || dev.bonded));
            }

            Layout.fillWidth: true
            iconName: Bluetooth.deviceIcon(dev)
            preferSymbolic: false
            tintIcon: false
            titleValue: label
            subtitleValue: showAddress ? address : ""
            badgeIcon: remembered ? "bookmark" : ""
            onClicked: root.deviceClicked(dev)
        }
    }

    MEmptyState {
        visible: root.emptyKey.length > 0 && root.devices.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: root.emptyIcon
        titleKey: root.emptyKey
    }
}
