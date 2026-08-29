import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: sectionModel }

    MSectionHeader { key: "settings.fields.kbLayout" }
    MSegmented {
        Layout.fillWidth: true
        value: sectionModel.kbLayout
        model: [
            { value: "de", titleKey: "settings.kbDe" },
            { value: "us", titleKey: "settings.kbUs" }
        ]
        onSelected: (v) => ConfigWrite.set("input.kbLayout", v)
    }

    MField {
        labelKey: "settings.fields.repeatRate"
        MSlider {
            from: 10
            to: 80
            value: Config.input.repeatRate ?? 25
            showValue: true
            onMoved: (v) => ConfigWrite.set("input.repeatRate", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.repeatDelay"
        MSlider {
            from: 150
            to: 1000
            value: Config.input.repeatDelay ?? 600
            showValue: true
            onMoved: (v) => ConfigWrite.set("input.repeatDelay", Math.round(v))
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.numlockOnBoot"
        MSwitch {
            checked: !!(Config.input.numlockOnBoot)
            onToggled: (v) => ConfigWrite.set("input.numlockOnBoot", v)
        }
    }

    MSectionHeader { key: "settings.fields.keybinds" }
    Repeater {
        model: sectionModel.rows.length
        MListItem {
            required property int index
            readonly property var row: sectionModel.rows[index] || ({})
            Layout.fillWidth: true
            titleKey: "cheatsheet.action." + (row.action || "")
            subtitleValue: row.combo || ""
        }
    }

    MButton {
        kind: "filled"
        key: "settings.openCheatsheet"
        iconName: "input-keyboard"
        onClicked: Cheatsheet.toggle()
    }
    MHint { key: "settings.hints.cheatsheetBind"; Layout.fillWidth: true }
}
