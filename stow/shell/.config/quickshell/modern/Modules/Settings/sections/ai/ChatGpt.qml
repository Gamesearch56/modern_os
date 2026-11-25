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
    readonly property bool _limited: Ai.chatgptBlock === "credits" || Ai.chatgptBlock === "spend"

    MText {
        key: {
            if (Ai.chatgptBlock === "credits")
                return "settings.chatgpt.needCredits";
            if (Ai.chatgptBlock === "spend")
                return "settings.chatgpt.needSpend";
            return Ai.chatgptHasKey ? "settings.chatgpt.connected" : "settings.chatgpt.needKey";
        }
        styleName: "titleSmall"
        color: root._limited ? Colors.color.error : (Ai.chatgptHasKey ? Colors.color.primary : Colors.color.onSurface)
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MHint {
        key: "settings.hints.chatgptAccount"
        Layout.fillWidth: true
    }

    MTextField {
        id: keyField
        Layout.fillWidth: true
        echoMode: keyField._masked ? TextInput.Normal : TextInput.Password
        placeholderKey: "settings.chatgpt.keyPlaceholder"
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
            key: "settings.chatgpt.connect"
            enabled: keyField.text.trim().length > 0 && !keyField._masked
            onClicked: {
                Ai.setChatGptKey(keyField.text);
                root._showMask();
            }
        }
        MButton {
            visible: Ai.chatgptHasKey
            kind: "outlined"
            key: "settings.chatgpt.signOut"
            onClicked: {
                Ai.clearChatGptKey();
                keyField._masked = false;
                keyField.text = "";
            }
        }
        MButton {
            visible: Ai.chatgptHasKey
            kind: "text"
            key: "settings.chatgpt.addCredits"
            onClicked: Ai.openChatGptBilling()
        }
        MButton {
            kind: "text"
            key: "settings.chatgpt.openKeys"
            onClicked: {
                Ai.openChatGptKeys();
                Settings.close();
            }
        }
    }

    function _showMask() {
        if (!Ai.chatgptHasKey) {
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
        function onChatgptHasKeyChanged() { root._showMask(); }
    }

    Component.onCompleted: root._showMask()
}
