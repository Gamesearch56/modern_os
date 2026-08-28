import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.titlebar" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.titlebar"
        MSwitch {
            checked: Config.windows?.titlebar ?? true
            onToggled: (v) => ConfigWrite.set("windows.titlebar", v)
        }
    }

    MSectionHeader { key: "settings.fields.windowRules" }
    Repeater {
        model: Config.windowRules || []
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.class || modelData.title || JSON.stringify(modelData)
        }
    }
    MEmptyState {
        visible: (Config.windowRules || []).length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 3
        iconName: "preferences-system-windows"
        titleKey: "settings.empty.rules"
    }
}
