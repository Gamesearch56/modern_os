import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    id: root
    spacing: Tokens.spacing.sm
    Component.onCompleted: SystemStats.watching = true
    Component.onDestruction: SystemStats.watching = false

    MIcon {
        visible: BarLayout.vertical
        name: "utilities-system-monitor-symbolic"
        size: Tokens.icon.md
    }

    MText {
        visible: !BarLayout.vertical
        value: I18n.t("performance.cpu") + " " + Math.round(SystemStats.cpuPercent) + "%"
        styleName: "labelSmall"
        familyRole: "monospace"
    }
    MText {
        visible: !BarLayout.vertical
        value: I18n.t("performance.ram") + " " + Math.round(SystemStats.ramPercent) + "%"
        styleName: "labelSmall"
        familyRole: "monospace"
    }
}
