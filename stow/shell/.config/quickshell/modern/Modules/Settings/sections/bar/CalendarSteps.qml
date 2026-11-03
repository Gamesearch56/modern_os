import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

// Numbered setup steps, one translation key per step.
ColumnLayout {
    id: root

    property var keys: []

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    Repeater {
        model: root.keys

        RowLayout {
            id: step

            required property int index
            required property string modelData

            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: Tokens.spacing.xl
                implicitHeight: Tokens.spacing.xl
                radius: width / 2
                color: Colors.color.secondaryContainer

                MText {
                    anchors.centerIn: parent
                    value: String(step.index + 1)
                    styleName: "labelMedium"
                    color: Colors.color.onSecondaryContainer
                }
            }
            MText {
                key: step.modelData
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
