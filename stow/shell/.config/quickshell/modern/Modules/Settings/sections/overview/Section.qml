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
    }
    Component.onDestruction: {
        Diagnostics.watching = false;
        SystemStats.watching = false;
    }

    DiagnosticsView {
        Layout.fillWidth: true
    }

    MSectionHeader {
        key: "settings.overview.stats"
        topMargin: Tokens.spacing.xxl
    }
    MPerfGrid {
        Layout.fillWidth: true
        cpuPercent: SystemStats.cpuPercent
        gpuPercent: SystemStats.gpuPercent
        ramPercent: SystemStats.ramPercent
        diskPercent: SystemStats.diskPercent
        cpuTemp: SystemStats.cpuTemp
        tempPercent: SystemStats.tempPercent
    }
}
