import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.xs
    Layout.fillWidth: true

    MField {
        labelKey: "settings.fields.calendarIcs"
        hintKey: "settings.hints.calendarIcs"
        MTextField {
            id: icsField
            text: Config.accounts?.calendarIcsUrl ?? ""
            placeholderKey: "settings.privacy.icsPlaceholder"
            onAccepted: root._save()
            onFocusedChanged: {
                if (!icsField.focused)
                    root._save();
            }
        }
    }

    function focusField() {
        icsField.forceActiveFocus();
    }

    function _save() {
        const u = String(icsField.text || "").trim();
        const cur = String(Config.accounts?.calendarIcsUrl ?? "").trim();
        if (u !== cur)
            ConfigWrite.set("accounts.calendarIcsUrl", u);
        Calendar.commitUrl(u);
    }

    Connections {
        target: Calendar
        function onLoadFailed() {
            Notifications.toast(I18n.t("settings.privacy.icsFailed"), "");
        }
    }
}
