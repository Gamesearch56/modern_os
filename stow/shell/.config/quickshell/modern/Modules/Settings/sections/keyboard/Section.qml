import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: sectionModel }

    MField {
        labelKey: "settings.fields.kbLayout"
        MSelect {
            value: sectionModel.kbLayout
            model: sectionModel.options
            onSelected: (v) => {
                ConfigWrite.set("input.kbLayout", v);
                Hypr.syncInput("input.kbLayout", v);
            }
        }
    }

    MField {
        labelKey: "settings.fields.repeatRate"
        hintKey: "settings.hints.repeatRate"
        MSlider {
            from: 10
            to: 80
            value: Config.input.repeatRate ?? 25
            showValue: true
            onMoved: (v) => Hypr.syncInput("input.repeatRate", Math.round(v))
            onCommitted: (v) => ConfigWrite.set("input.repeatRate", Math.round(v))
        }
    }

    MField {
        labelKey: "settings.fields.repeatDelay"
        hintKey: "settings.hints.repeatDelay"
        MSlider {
            from: 150
            to: 1000
            value: Config.input.repeatDelay ?? 600
            showValue: true
            onMoved: (v) => Hypr.syncInput("input.repeatDelay", Math.round(v))
            onCommitted: (v) => ConfigWrite.set("input.repeatDelay", Math.round(v))
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.numlockOnBoot"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: !!(Config.input.numlockOnBoot)
                onToggled: (v) => {
                    ConfigWrite.set("input.numlockOnBoot", v);
                    Hypr.syncInput("input.numlockOnBoot", v);
                }
            }
        }
        MHint {
            key: "settings.hints.numlockOnBoot"
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.mouseSideButtons"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: Config.input.mouseSideButtons !== false
                onToggled: (v) => ConfigWrite.set("input.mouseSideButtons", v)
            }
        }
        MHint {
            key: "settings.hints.mouseSideButtons"
            Layout.fillWidth: true
        }
    }

    MButton {
        kind: "tonal"
        key: "settings.openCheatsheet"
        iconName: "input-keyboard"
        onClicked: Cheatsheet.show()
    }
}
