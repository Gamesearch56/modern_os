import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root

    visible: Battery.hasBattery
    implicitWidth: visible ? hit.implicitWidth : 0
    implicitHeight: Config.bar.height

    Component.onCompleted: Battery.watch()
    Component.onDestruction: Battery.unwatch()

    BarIconLabel {
        id: hit
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
