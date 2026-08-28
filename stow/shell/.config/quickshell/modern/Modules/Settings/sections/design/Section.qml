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
        key: "settings.sections.design"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.activeProfile"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.activeProfile
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.transparency"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: Number(model.transparency).toFixed(2)
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.cornerRounding"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: Number(model.cornerRounding).toFixed(2)
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
