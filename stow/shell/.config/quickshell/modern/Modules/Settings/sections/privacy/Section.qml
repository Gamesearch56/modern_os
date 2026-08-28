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
        key: "settings.sections.privacy"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.dnd"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.dndText
        styleName: "bodyMedium"
        familyRole: "monospace"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.kdeconnect"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.kdeconnectText
        styleName: "bodyMedium"
        familyRole: "monospace"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
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
