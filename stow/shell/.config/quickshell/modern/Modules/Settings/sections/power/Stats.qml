import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

GridLayout {
    id: root

    visible: Battery.hasBattery
    columns: 2
    columnSpacing: Tokens.spacing.xs
    rowSpacing: Tokens.spacing.xs
    Layout.fillWidth: true

    readonly property string _none: I18n.t("settings.energy.unavailable")

    MPercentTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        titleKey: "settings.energy.draw"
        valueText: Battery.rateWatts > 0
            ? I18n.t("settings.energy.watts", ({ n: Math.round(Battery.rateWatts * 10) / 10 }))
            : root._none
        showTrack: false
    }
    MPercentTile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        titleKey: "settings.energy.health"
        valueText: Battery.healthPercent > 0
            ? I18n.t("settings.energyBattery", ({ n: Battery.healthPercent }))
            : root._none
        percent: Battery.healthPercent
        showTrack: Battery.healthPercent > 0
    }
}
