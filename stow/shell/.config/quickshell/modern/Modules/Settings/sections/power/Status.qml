import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MStatusCard {
    id: root

    iconName: Battery.hasBattery ? Battery.iconName : "ac-adapter"
    iconColor: Colors.color.primary
    titleValue: Battery.hasBattery
        ? I18n.t("settings.energyBattery", ({ n: Battery.percent }))
        : I18n.t("settings.energy.onAc")
    subtitleValue: Battery.hasBattery ? root._subtitle : ""

    readonly property string _subtitle: {
        if (!Battery.hasBattery)
            return I18n.t("settings.energy.onAc");
        if (Battery.charging && Battery.percent < 100)
            return I18n.t("settings.energy.charging");
        if (Battery.onBattery)
            return I18n.t("settings.energy.onBattery");
        return I18n.t("settings.energy.pluggedIn");
    }

    detail: Flow {
        visible: Battery.hasBattery && (Battery.timeLabel.length > 0 || Battery.rateWatts > 0)
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs

        Rectangle {
            visible: Battery.timeLabel.length > 0
            implicitHeight: Tokens.spacing.xl
            implicitWidth: timeLab.implicitWidth + Tokens.spacing.md * 2
            radius: Tokens.radius.full
            color: Colors.color.surfaceContainerHighest
            MText {
                id: timeLab
                anchors.centerIn: parent
                value: Battery.timeLabel
                styleName: "labelLarge"
            }
        }
        Rectangle {
            visible: Battery.rateWatts > 0
            implicitHeight: Tokens.spacing.xl
            implicitWidth: wattLab.implicitWidth + Tokens.spacing.md * 2
            radius: Tokens.radius.full
            color: Colors.color.surfaceContainerHighest
            MText {
                id: wattLab
                anchors.centerIn: parent
                value: I18n.t("settings.energy.watts", ({ n: Math.round(Battery.rateWatts * 10) / 10 }))
                styleName: "labelLarge"
            }
        }
    }

    Loader {
        active: Battery.hasBattery
        visible: active
        Layout.fillWidth: true
        Layout.preferredHeight: active ? Tokens.spacing.xxl + Tokens.spacing.md : 0
        sourceComponent: spark
    }

    Component {
        id: spark
        MSparkline {
            values: Battery.percentSamples
            fillColor: Battery.onBattery ? Colors.color.tertiary : Colors.color.primary
        }
    }
}
