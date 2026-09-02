import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.sm

    MText {
        key: "bar.performance"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MPerfGrid {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.xs
        cpuPercent: SystemStats.cpuPercent
        gpuPercent: SystemStats.gpuPercent
        ramPercent: SystemStats.ramPercent
        diskPercent: SystemStats.diskPercent
        cpuTemp: SystemStats.cpuTemp
        tempPercent: SystemStats.tempPercent
    }
}
