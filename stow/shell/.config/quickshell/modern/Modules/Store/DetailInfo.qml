import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

ColumnLayout {
    id: root

    property var info: ({})

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.md
        rowSpacing: Tokens.spacing.xs

        MText {
            key: "store.version"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MText {
            value: String(root.info.version || "")
            styleName: "bodyMedium"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        MText {
            key: "store.size"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MText {
            value: String(root.info.isize || "")
            styleName: "bodyMedium"
            Layout.fillWidth: true
        }
        MText {
            key: "store.license"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MText {
            value: String(root.info.licenses || "")
            styleName: "bodyMedium"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
