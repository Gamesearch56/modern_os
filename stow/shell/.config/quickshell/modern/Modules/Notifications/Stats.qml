import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.md

    MText {
        styleName: "labelSmall"
        Layout.fillWidth: true
        value: I18n.t("performance.cpu") + " " + Math.round(SystemStats.cpuPercent) + "%"
    }
    MText {
        styleName: "labelSmall"
        Layout.fillWidth: true
        value: I18n.t("performance.ram") + " " + Math.round(SystemStats.ramPercent) + "%"
    }
    MText {
        styleName: "labelSmall"
        Layout.fillWidth: true
        value: I18n.t("performance.disk") + " " + Math.round(SystemStats.diskPercent) + "%"
    }
}
