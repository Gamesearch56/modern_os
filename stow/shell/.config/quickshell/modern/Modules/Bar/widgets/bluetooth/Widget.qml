import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: chip.implicitWidth
    implicitHeight: BarLayout.height

    readonly property string _device: {
        const list = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i].name || "";
        }
        return "";
    }

    BarIconLabel {
        id: chip
        anchors.centerIn: parent
        iconName: Bluetooth.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
        key: "bar.bluetooth"
        label: root._device
        showLabel: !BarLayout.vertical
        checked: Settings.open && Settings.sectionId === "bluetooth"
        onClicked: Settings.openAt("bluetooth", "")
    }
}
