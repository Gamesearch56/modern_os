import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.xxs

    MText {
        key: "bar.performance"
        styleName: "labelSmall"
        color: Colors.color.onSurfaceVariant
        font.capitalization: Font.AllUppercase
        Layout.fillWidth: true
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "performance.cpu"
        MText {
            value: Math.round(SystemStats.cpuPercent) + "%"
            styleName: "labelLarge"
            familyRole: "monospace"
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "performance.ram"
        MText {
            value: Math.round(SystemStats.ramPercent) + "%"
            styleName: "labelLarge"
            familyRole: "monospace"
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "performance.disk"
        MText {
            value: Math.round(SystemStats.diskPercent) + "%"
            styleName: "labelLarge"
            familyRole: "monospace"
        }
    }
    MListItem {
        visible: Config.widgets.performance?.showGpu ?? true
        Layout.fillWidth: true
        titleKey: "performance.gpu"
        MText {
            value: Math.round(SystemStats.gpuPercent) + "%"
            styleName: "labelLarge"
            familyRole: "monospace"
        }
    }
    MListItem {
        visible: SystemStats.fanRpm > 0
        Layout.fillWidth: true
        titleKey: "performance.fan"
        MText {
            value: String(SystemStats.fanRpm)
            styleName: "labelLarge"
            familyRole: "monospace"
        }
    }
}
