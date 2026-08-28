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
        key: "settings.sections.launcher"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.launcherResults"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: String(model.resultCount)
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.frecency"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.frecencyEnabled ? I18n.t("settings.on") : I18n.t("settings.off")
        styleName: "bodyMedium"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.providers"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.providersText
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
