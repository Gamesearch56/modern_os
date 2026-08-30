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
        MouseArea {
            required property int index
            readonly property var dev: root.devices[index]
            readonly property string label: Bluetooth.deviceLabel(dev)
            readonly property string iconName: Bluetooth.deviceIcon(dev)
            readonly property string address: dev && dev.address ? String(dev.address) : ""
            readonly property bool showAddress: address.length > 0 && address !== label
            readonly property bool remembered: {
                void dev?.paired;
                void dev?.bonded;
                return !!(dev && (dev.paired || dev.bonded));
            }

            Layout.fillWidth: true
            implicitHeight: row.implicitHeight
            implicitWidth: row.implicitWidth
            cursorShape: Qt.PointingHandCursor
            onClicked: root.deviceClicked(dev)

            RowLayout {
                id: row
                width: parent.width
                spacing: Tokens.spacing.md

                MIcon {
                    name: iconName
                    size: Tokens.icon.md
                    tint: false
                    preferSymbolic: false
                }
                ColumnLayout {
                    spacing: Tokens.spacing.xxs
                    Layout.fillWidth: true
                    MText {
                        value: label
                        styleName: "bodyLarge"
                        Layout.fillWidth: true
                    }
                    MText {
                        visible: showAddress
                        value: address
                        styleName: "bodySmall"
                        color: Colors.color.onSurfaceVariant
                        Layout.fillWidth: true
                    }
                }
                MIcon {
                    visible: remembered
                    name: "bookmark"
                    size: Tokens.icon.sm
                    color: Colors.color.primary
                    Accessible.role: Accessible.StaticText
                    Accessible.name: I18n.t("settings.bluetooth.remembered")
                }
            }
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
