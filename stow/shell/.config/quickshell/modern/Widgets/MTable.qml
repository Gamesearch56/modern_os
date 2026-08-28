// Two-column table chrome: header row plus a fill body slot. Cheatsheet
// uses keys | action; other sections can host arbitrary rows.
import QtQuick
import QtQuick.Layouts
import "../Commons"

ColumnLayout {
    id: root

    property string leftKey: ""
    property string rightKey: ""

    default property alias extra: body.data

    spacing: Tokens.spacing.xs
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MText {
            key: root.leftKey
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: Tokens.spacing.xxl * 8
        }

        MText {
            key: root.rightKey
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
    }

    MDivider {
        Layout.fillWidth: true
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
    }
}
