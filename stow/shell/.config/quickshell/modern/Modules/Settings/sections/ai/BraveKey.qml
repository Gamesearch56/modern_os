import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    function _save() {
        const key = keyField.text.trim();
        if (!key.length)
            return;
        AiSearch.setKey(key);
        keyField.text = "";
    }

    MField {
        labelKey: "settings.fields.braveKey"
        hintKey: "settings.hints.braveKey"
        MTextField {
            id: keyField
            placeholderKey: "settings.brave.keyPlaceholder"
            maximumLength: 256
            onAccepted: root._save()
        }
    }

    MHint {
        visible: AiSearch.hasKey && keyField.text.trim().length === 0
        key: "settings.brave.saved"
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MButton {
            kind: "filled"
            key: "settings.brave.save"
            enabled: keyField.text.trim().length > 0
            onClicked: root._save()
        }
        MButton {
            visible: AiSearch.hasKey
            kind: "text"
            key: "settings.brave.remove"
            onClicked: {
                AiSearch.setKey("");
                keyField.text = "";
            }
        }
        MButton {
            kind: "text"
            key: "settings.brave.getKey"
            onClicked: {
                AiSearch.openKeys();
                Settings.close();
            }
        }
    }
}
