import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.workspaceMode" }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.wsDynamic"
            checked: (Config.monitors?.workspaceMode || "dynamic") === "dynamic"
            onClicked: ConfigWrite.set("monitors.workspaceMode", "dynamic")
        }
        MChip {
            key: "settings.wsFixed"
            checked: Config.monitors?.workspaceMode === "fixed"
            onClicked: ConfigWrite.set("monitors.workspaceMode", "fixed")
        }
    }
    MHint { key: "settings.hints.workspaceMode"; Layout.fillWidth: true }

    MSectionHeader { key: "settings.fields.monitors" }
    Repeater {
        model: Hypr.monitors?.values ?? []
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.description || modelData.name || ""
            subtitleValue: (modelData.width || "") + "×" + (modelData.height || "") + " @" + (modelData.scale || 1)
        }
    }
}
