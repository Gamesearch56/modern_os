import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    visible: Battery.hasBattery && (root._energy.length > 0 || Battery.cycles >= 0 || Battery.voltage > 0)
    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    readonly property string _energy: {
        if (Battery.energyWh <= 0)
            return "";
        if (Battery.energyFullWh > 0)
            return I18n.t("settings.energy.energyOf", ({
                now: Battery.formatWh(Battery.energyWh),
                full: Battery.formatWh(Battery.energyFullWh)
            }));
        return I18n.t("settings.energy.energyWh", ({ n: Number(Battery.formatWh(Battery.energyWh)) }));
    }

    RowLayout {
        visible: root._energy.length > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.energy.energy"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            value: root._energy
            styleName: "labelLarge"
        }
    }
    RowLayout {
        visible: Battery.cycles >= 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.energy.cycles"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            value: String(Battery.cycles)
            styleName: "labelLarge"
        }
    }
    RowLayout {
        visible: Battery.voltage > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.energy.voltage"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            value: I18n.t("settings.energy.volts", ({ n: Math.round(Battery.voltage * 10) / 10 }))
            styleName: "labelLarge"
        }
    }
}
