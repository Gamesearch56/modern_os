import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property string _mask: "************"

    MText {
        key: Ai.ready ? "settings.gemini.connected" : "settings.gemini.needKey"
        styleName: "titleSmall"
        color: Ai.ready ? Colors.color.primary : Colors.color.onSurface
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MHint {
        key: "settings.hints.geminiAccount"
        Layout.fillWidth: true
    }

    MTextField {
        id: keyField
        Layout.fillWidth: true
        echoMode: keyField._masked ? TextInput.Normal : TextInput.Password
        placeholderKey: "settings.gemini.keyPlaceholder"
        maximumLength: 256
        onTextEdited: {
            if (keyField.text === root._mask)
                return;
            keyField._masked = false;
        }
        property bool _masked: false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MButton {
            kind: "filled"
            key: "settings.gemini.connect"
            enabled: keyField.text.trim().length > 0 && !keyField._masked
            onClicked: {
                Ai.setGeminiKey(keyField.text);
                root._showMask();
            }
        }
        MButton {
            visible: Ai.geminiHasKey
            kind: "outlined"
            key: "settings.gemini.signOut"
            onClicked: {
                Ai.clearGeminiKey();
                keyField._masked = false;
                keyField.text = "";
            }
        }
        MButton {
            kind: "text"
            key: "settings.gemini.openStudio"
            onClicked: {
                Ai.openGeminiStudio();
                Settings.close();
            }
        }
    }

    function _showMask() {
        if (!Ai.geminiHasKey) {
            if (keyField._masked) {
                keyField._masked = false;
                keyField.text = "";
            }
            return;
        }
        keyField._masked = true;
        keyField.text = root._mask;
    }

    Connections {
        target: Ai
        function onGeminiHasKeyChanged() { root._showMask(); }
    }

    Component.onCompleted: root._showMask()
}
