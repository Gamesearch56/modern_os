import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: sectionModel }

    MText {
        key: "settings.sections.keyboard"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.keybinds"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    Repeater {
        model: sectionModel.rows
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleKey: "cheatsheet.action." + modelData.action
            subtitleValue: modelData.combo
        }
    }

    MText {
        key: "settings.cliNote"
        styleName: "bodySmall"
        color: Colors.color.onSurfaceVariant
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }
}
