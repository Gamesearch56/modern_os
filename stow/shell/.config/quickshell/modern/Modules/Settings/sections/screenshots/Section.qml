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
        key: "settings.sections.screenshots"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.screenshotDir"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.directory
        styleName: "bodyMedium"
        familyRole: "monospace"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.screenshotFormat"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.format
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.copyClipboard"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.copyToClipboard ? I18n.t("settings.on") : I18n.t("settings.off")
        styleName: "bodyMedium"
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
