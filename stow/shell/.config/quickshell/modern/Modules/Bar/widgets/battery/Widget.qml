import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root

    // Clip to the slot the bar layout assigns; otherwise the label keeps
    // its own width and draws under the control and power buttons.
    clip: true
    readonly property real _w: Math.max(hit.implicitWidth, BarLayout.height)
    implicitWidth: Battery.hasBattery ? root._w : 0
    implicitHeight: BarLayout.height
    width: implicitWidth
    height: implicitHeight
    visible: Battery.hasBattery

    Component.onCompleted: Battery.watch()
    Component.onDestruction: Battery.unwatch()

    BarIconLabel {
        id: hit
        width: implicitWidth
        height: BarLayout.height
        iconName: Battery.iconName
        key: "bar.battery"
        label: String(Battery.percent) + "%"
        showLabel: !BarLayout.vertical
        checked: Settings.open && Settings.sectionId === "power"
        alert: Battery.percent <= 15 && !Battery.charging
        onClicked: {
            if (Settings.open && Settings.sectionId === "power")
                Settings.close();
            else
                Settings.openAt("power", "");
        }
    }
}
