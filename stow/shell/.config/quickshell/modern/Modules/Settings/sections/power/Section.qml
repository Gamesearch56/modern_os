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
        key: "settings.sections.power"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.buttonAction"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.buttonAction
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.lidAc"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.lidActionAc
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.lidBattery"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.lidActionBattery
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
