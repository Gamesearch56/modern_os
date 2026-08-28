import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "help-about"
        key: "ai.title"
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        width: Tokens.spacing.xxl * 12
        height: Tokens.spacing.xxl * 14
        y: root.height + Tokens.spacing.sm
        x: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: Ai.history
                delegate: MListItem {
                    required property var modelData
                    width: ListView.view.width
                    titleValue: modelData.role === "user" ? I18n.t("ai.you") : I18n.t("ai.assistant")
                    subtitleValue: modelData.text || ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                MTextField {
                    id: field
                    Layout.fillWidth: true
                    placeholderKey: "ai.placeholder"
                    onAccepted: {
                        Ai.chat(text);
                        text = "";
                    }
                }
                MIconButton {
                    iconName: "document-send"
                    enabled: !Ai.busy
                    onClicked: {
                        Ai.chat(field.text);
                        field.text = "";
                    }
                }
            }
        }
    }
}
