import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    Component.onCompleted: {
        Diagnostics.watching = true;
        SystemStats.watching = true;
        Battery.watching = true;
    }
    Component.onDestruction: {
        Diagnostics.watching = false;
        SystemStats.watching = false;
        Battery.watching = false;
    }

    DiagnosticsView {
        Layout.fillWidth: true
    }

    MSectionHeader { key: "settings.overview.stats" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.sm
        rowSpacing: Tokens.spacing.sm

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
            visible: SystemStats.gpuPercent > 0
            Layout.fillWidth: true
            titleKey: "performance.gpu"
            valueText: Math.round(SystemStats.gpuPercent) + "%"
            percent: SystemStats.gpuPercent
        }
    }
    MSparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl + Tokens.spacing.md
        values: SystemStats.cpuSamples
    }
}
