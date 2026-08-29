import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root
    implicitWidth: Tokens.spacing.xxl * 12
    spacing: Tokens.spacing.sm

    function previewUrl(data: var): string {
        if (!data)
            return "";
        const img = data.image;
        if (img === undefined || img === null)
            return "";
        const s = String(img);
        if (!s.length || s === "undefined")
            return "";
        if (s.indexOf("://") !== -1)
            return s;
        return "file://" + s;
    }

    Repeater {
        model: Notifications.list.slice(0, 3)

        MCard {
            required property var modelData
            readonly property string preview: root.previewUrl(modelData)
            Layout.fillWidth: true
            Layout.preferredHeight: preview.length > 0
                ? Tokens.spacing.xxl * 4
                : Tokens.spacing.xxl * 3
            level: 2
            borderWidth: toastHover.hovered ? 2 : 1
            borderColor: toastHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

            HoverHandler {
                id: toastHover
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.sm

                Rectangle {
                    visible: preview.length > 0
                    Layout.preferredWidth: Tokens.spacing.xxl * 3
                    Layout.preferredHeight: Tokens.spacing.xxl * 2
                    Layout.alignment: Qt.AlignVCenter
                    radius: Tokens.radius.small
                    color: Colors.color.surfaceContainerHighest
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: preview
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Tokens.spacing.xxl * 3
                        sourceSize.height: Tokens.spacing.xxl * 2
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MText {
                        Layout.fillWidth: true
                        value: modelData.summary || modelData.appName || ""
                        styleName: "titleSmall"
                    }

                    MText {
                        Layout.fillWidth: true
                        visible: (modelData.body || "").length > 0
                        value: modelData.body || ""
                        styleName: "bodySmall"
                        color: Colors.color.onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }

                MIconButton {
                    iconName: "window-close"
                    key: "bar.close"
                    onClicked: Notifications.dismiss(modelData)
                }
            }
        }
    }
}
