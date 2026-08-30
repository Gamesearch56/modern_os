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
        MSegmented {
            value: sectionModel.kbLayout
            model: [
                { value: "de", titleKey: "settings.kbDe" },
                { value: "us", titleKey: "settings.kbUs" }
            ]
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
            onMoved: (v) => {
                const n = Math.round(v);
                ConfigWrite.set("input.repeatRate", n);
                Hypr.syncInput("input.repeatRate", n);
            }
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
            onMoved: (v) => {
                const n = Math.round(v);
                ConfigWrite.set("input.repeatDelay", n);
                Hypr.syncInput("input.repeatDelay", n);
            }
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

    MButton {
        kind: "tonal"
        key: "settings.openCheatsheet"
        iconName: "input-keyboard"
        onClicked: Cheatsheet.show()
    }
}
