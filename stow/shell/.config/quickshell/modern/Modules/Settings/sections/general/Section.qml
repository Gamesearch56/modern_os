import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: model }

    MText {
        key: "settings.sections.general"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.motionScale"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MSlider {
        from: 0
        to: 2
        value: model.motionScale
        Layout.fillWidth: true
        onMoved: (v) => {
            const r = Math.round(v * 10) / 10;
            ConfigWrite.set("motion.scale", r);
        }
    }

    MText {
        value: Number(model.motionScale).toFixed(1)
        styleName: "bodyMedium"
        familyRole: "monospace"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.autologin"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.autologin ? I18n.t("settings.on") : I18n.t("settings.off")
        styleName: "bodyMedium"
        Layout.fillWidth: true
    }

    MText {
        key: "settings.fields.idleTimings"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: model.idleText
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
