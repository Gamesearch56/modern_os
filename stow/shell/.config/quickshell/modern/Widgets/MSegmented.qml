// Exclusive segmented control. `model` is [{ value, titleKey?, titleValue? }].
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property var model: []
    property var value: ""
    property bool enabled: true

    signal selected(var value)

    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    implicitWidth: row.implicitWidth + Tokens.spacing.xs * 2
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Tokens.spacing.xxs
        spacing: Tokens.spacing.xxs

        Repeater {
            model: root.model

            Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: Tokens.spacing.xxl * 3

                readonly property bool on: String(modelData.value) === String(root.value)

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: parent.on ? Chrome.filled.bg : "transparent"
                }

                MText {
                    anchors.centerIn: parent
                    key: modelData.titleKey || ""
                    value: modelData.titleValue || ""
                    styleName: "labelLarge"
                    color: parent.on ? Chrome.filled.fg : Colors.color.onSurface
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(modelData.value)
                }
            }
        }
    }
}
