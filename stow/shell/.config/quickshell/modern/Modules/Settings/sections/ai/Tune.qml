import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property bool thinking: Config.accounts?.ai?.thinking === true
    readonly property bool brief: Config.accounts?.ai?.brief !== false

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.aiThinking"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: root.thinking
            nameKey: "settings.fields.aiThinking"
            onToggled: (v) => ConfigWrite.set("accounts.ai.thinking", v)
        }
    }
    MHint {
        key: "settings.hints.aiThinking"
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.aiBrief"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: root.brief
            nameKey: "settings.fields.aiBrief"
            onToggled: (v) => ConfigWrite.set("accounts.ai.brief", v)
        }
    }
    MHint {
        key: "settings.hints.aiBrief"
        Layout.fillWidth: true
    }
}
