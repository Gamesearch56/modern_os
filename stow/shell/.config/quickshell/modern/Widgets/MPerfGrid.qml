// CPU / GPU / RAM / DISK tiles with Fan full-width below. Bind percents
// from SystemStats in the Module — Widgets must not import Services.
import QtQuick
import QtQuick.Layouts
import "../Commons"

GridLayout {
    id: root

    property real cpuPercent: 0
    property real gpuPercent: 0
    property real ramPercent: 0
    property real diskPercent: 0
    property real fanPercent: 0
    property int fanRpm: 0
    property bool showGpu: Config.widgets.performance?.showGpu ?? true

    columns: 2
    columnSpacing: Tokens.spacing.xs
    rowSpacing: Tokens.spacing.xs

    MPercentTile {
        Layout.fillWidth: true
        titleKey: "performance.cpu"
        valueText: Math.round(root.cpuPercent) + "%"
        percent: root.cpuPercent
    }
    MPercentTile {
        visible: root.showGpu
        Layout.fillWidth: true
        titleKey: "performance.gpu"
        valueText: Math.round(root.gpuPercent) + "%"
        percent: root.gpuPercent
    }
    MPercentTile {
        Layout.fillWidth: true
        titleKey: "performance.ram"
        valueText: Math.round(root.ramPercent) + "%"
        percent: root.ramPercent
    }
    MPercentTile {
        Layout.fillWidth: true
        titleKey: "performance.disk"
        valueText: Math.round(root.diskPercent) + "%"
        percent: root.diskPercent
    }
    MPercentTile {
        Layout.fillWidth: true
        Layout.columnSpan: 2
        titleKey: "performance.fan"
        valueText: String(root.fanRpm)
        percent: root.fanPercent
    }
}
