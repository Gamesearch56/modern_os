import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: chip.implicitWidth
    implicitHeight: BarLayout.height

    readonly property string _device: Bluetooth.deviceLabel(Bluetooth.connectedDevices[0])

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
