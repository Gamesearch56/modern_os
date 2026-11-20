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

            Layout.fillWidth: true
            iconName: Bluetooth.deviceIcon(dev)
            preferSymbolic: false
            tintIcon: false
            titleValue: label
            subtitleValue: showAddress ? address : ""
            onClicked: root.deviceClicked(dev)

            Rectangle {
                visible: remembered
                implicitHeight: Tokens.spacing.lg + Tokens.spacing.xs
                implicitWidth: savedLabel.implicitWidth + Tokens.spacing.sm * 2
                radius: Tokens.radius.full
                color: Colors.color.primaryContainer
                Accessible.role: Accessible.StaticText
                Accessible.name: I18n.t("settings.bluetooth.remembered")

                MText {
                    id: savedLabel
                    anchors.centerIn: parent
                    key: "settings.bluetooth.remembered"
                    styleName: "labelSmall"
                    color: Colors.color.onPrimaryContainer
                }
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
