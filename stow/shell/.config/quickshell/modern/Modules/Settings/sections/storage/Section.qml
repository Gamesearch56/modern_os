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
        key: "settings.sections.storage"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.snapper"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.snapperEnabled ? I18n.t("settings.on") : I18n.t("settings.off")
        styleName: "bodyMedium"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.restic"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.resticEnabled ? I18n.t("settings.on") : I18n.t("settings.off")
        styleName: "bodyMedium"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.preUpdateSnapshot"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.preUpdateSnapshot ? I18n.t("settings.on") : I18n.t("settings.off")
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
