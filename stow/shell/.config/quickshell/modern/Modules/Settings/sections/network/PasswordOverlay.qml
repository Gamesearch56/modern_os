import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MOverlay {
    id: root
    property var net: null
    property string password: ""
    open: root.net !== null
    titleKey: "settings.fields.wifiPassword"
    titleValue: root.net ? (root.net.ssid || root.net.name || "") : ""
    cardHeight: Tokens.spacing.xxl * 8
    onClosed: root.password = ""
    onOpenChanged: {
        if (root.open)
            Qt.callLater(() => pwdField.focusToType());
    }

    ColumnLayout {
        spacing: Tokens.spacing.md

        MField {
            labelKey: "settings.fields.wifiPassword"
            MTextField {
                id: pwdField
                echoMode: TextInput.Password
                onTextEdited: root.password = text
                onAccepted: {
                    if (root.net)
                        Network.connect(root.net, root.password);
                    root.password = "";
                    root.closed();
                }
            }
        }
        MButton {
            kind: "filled"
            key: "settings.connectWifi"
            onClicked: {
                if (root.net)
                    Network.connect(root.net, root.password);
                root.password = "";
                root.closed();
            }
        }
    }
}
