import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.xs
    implicitHeight: Tokens.spacing.xxl

    readonly property string _device: {
        const list = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i].name || "";
        }
        return "";
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIconButton {
            tabFocus: false
            iconName: Bluetooth.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            key: "bar.bluetooth"
            onClicked: Settings.openAt("bluetooth", "")
        }

        MText {
            visible: root._device.length > 0
            value: root._device
            styleName: "labelSmall"
            elide: Text.ElideRight
            Layout.maximumWidth: Tokens.spacing.xxl * 4
        }
    }
}
