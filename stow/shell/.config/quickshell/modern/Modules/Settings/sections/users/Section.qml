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
        key: "settings.sections.users"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "users.title"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.gated"
        styleName: "bodyMedium"
        wrapMode: Text.WordWrap
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
