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

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.xs
        columns: 2
        columnSpacing: Tokens.spacing.xs
        rowSpacing: Tokens.spacing.xs

        MPercentTile {
            Layout.fillWidth: true
            titleKey: "performance.cpu"
            valueText: Math.round(SystemStats.cpuPercent) + "%"
            percent: SystemStats.cpuPercent
        }
        MPercentTile {
            Layout.fillWidth: true
            titleKey: "performance.ram"
            valueText: Math.round(SystemStats.ramPercent) + "%"
            percent: SystemStats.ramPercent
        }
        MPercentTile {
            Layout.fillWidth: true
            titleKey: "performance.disk"
            valueText: Math.round(SystemStats.diskPercent) + "%"
            percent: SystemStats.diskPercent
        }
        MPercentTile {
            visible: Config.widgets.performance?.showGpu ?? true
            Layout.fillWidth: true
            titleKey: "performance.gpu"
            valueText: Math.round(SystemStats.gpuPercent) + "%"
            percent: SystemStats.gpuPercent
        }
        MPercentTile {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            titleKey: "performance.fan"
            valueText: String(SystemStats.fanRpm)
            percent: SystemStats.fanPercent
        }
    }
}
