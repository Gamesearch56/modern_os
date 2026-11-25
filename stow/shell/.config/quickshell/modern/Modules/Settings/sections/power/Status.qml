import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    readonly property string _headline: {
        if (!Battery.hasBattery)
            return "";
        if (Battery.full)
            return I18n.t("settings.energy.full");
        if (Battery.charging && Battery.untilFullLabel.length > 0)
            return I18n.t("settings.energy.untilFullIn", ({ t: Battery.untilFullLabel }));
        if (Battery.onBattery && Battery.remainingLabel.length > 0)
            return I18n.t("settings.energy.remainingIn", ({ t: Battery.remainingLabel }));
        if (Battery.charging)
            return I18n.t("settings.energy.charging");
        return I18n.t("settings.energy.onBattery");
    }

    readonly property string _state: {
        if (!Battery.hasBattery)
            return I18n.t("settings.energy.onAc");
        if (Battery.full)
            return I18n.t("settings.energy.pluggedIn");
        if (Battery.charging)
            return I18n.t("settings.energy.charging");
        if (Battery.onBattery)
            return I18n.t("settings.energy.onBattery");
        return I18n.t("settings.energy.pluggedIn");
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MIcon {
                name: Battery.hasBattery ? Battery.iconName : "battery-ac-adapter-symbolic"
                size: Tokens.spacing.xxl * 2
                color: Battery.hasBattery && Battery.percent <= 15 && !Battery.charging
                    ? Colors.color.error : Colors.color.primary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.xs

                MText {
                    value: Battery.hasBattery
                        ? I18n.t("settings.energyBattery", ({ n: Battery.percent }))
                        : I18n.t("settings.energy.onAc")
                    styleName: "titleLarge"
                    Layout.fillWidth: true
                }
                MText {
                    value: root._state
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
        }

        MText {
            visible: Battery.hasBattery && root._headline.length > 0
            value: root._headline
            styleName: "displaySmall"
            color: Colors.color.primary
            Layout.fillWidth: true
        }

        MLinearProgress {
            visible: Battery.hasBattery
            Layout.fillWidth: true
            value: Battery.percent / 100
        }
    }
}
