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

    MButton {
        kind: "filled"
        key: "settings.openCheatsheet"
        iconName: "input-keyboard"
        onClicked: Cheatsheet.toggle()
    }
    MHint { key: "settings.hints.cheatsheetBind"; Layout.fillWidth: true }
}
