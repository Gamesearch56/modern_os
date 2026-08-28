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
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.kbDe"
            checked: sectionModel.kbLayout === "de"
            onClicked: ConfigWrite.set("input.kbLayout", "de")
        }
        MChip {
            key: "settings.kbUs"
            checked: sectionModel.kbLayout === "us"
            onClicked: ConfigWrite.set("input.kbLayout", "us")
        }
    }

    MSectionHeader { key: "settings.fields.keybinds" }
    Repeater {
        model: sectionModel.rows
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleKey: "cheatsheet.action." + modelData.action
            Row {
                spacing: Tokens.spacing.xs
                Repeater {
                    model: String(modelData.combo).split(" + ")
                    MKeycap {
                        required property string modelData
                        value: modelData
                    }
                }
            }
        }
    }
}
