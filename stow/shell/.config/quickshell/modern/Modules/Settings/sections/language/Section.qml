import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: model }

    MText {
        key: "settings.sections.language"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.languageUi"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.ui
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.langEn"
            checked: model.ui === "en"
            onClicked: ConfigWrite.set("language.ui", "en")
        }
        MChip {
            key: "settings.langDe"
            checked: model.ui === "de"
            onClicked: ConfigWrite.set("language.ui", "de")
        }
    }

    MText {
        key: "settings.fields.dateFormat"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.dateFormat
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.timeFormat"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.timeFormat
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
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
