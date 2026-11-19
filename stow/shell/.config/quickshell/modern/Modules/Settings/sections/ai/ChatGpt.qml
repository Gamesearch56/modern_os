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
        key: Ai.chatgptHasKey ? "settings.chatgpt.connected" : "settings.chatgpt.needKey"
        styleName: "titleSmall"
        color: Ai.chatgptHasKey ? Colors.color.primary : Colors.color.onSurface
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
