import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.frecency"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: !!(Config.launcher.frecencyEnabled)
                onToggled: (v) => ConfigWrite.set("launcher.frecencyEnabled", v)
            }
        }
        MHint {
            key: "settings.hints.frecency"
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.showIcons"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.launcher.showIcons)
            onToggled: (v) => ConfigWrite.set("launcher.showIcons", v)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.showDescriptions"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.launcher.showDescriptions)
            onToggled: (v) => ConfigWrite.set("launcher.showDescriptions", v)
        }
    }

    MField {
        labelKey: "settings.fields.launcherResults"
        MSlider {
            from: 4
            to: 20
            value: Config.launcher.resultCount ?? 9
            showValue: true
            onCommitted: (v) => ConfigWrite.set("launcher.resultCount", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.mostUsed"
        MSlider {
            from: 4
            to: 16
            value: Config.launcher.mostUsedGridSize ?? 8
            showValue: true
            onCommitted: (v) => ConfigWrite.set("launcher.mostUsedGridSize", Math.round(v))
        }
    }
}
