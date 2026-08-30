import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

RowLayout {
    id: root

    property string labelKey: ""
    property string value: ""

    visible: root.value.length > 0
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    MText {
        key: root.labelKey
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
        Layout.preferredWidth: Tokens.spacing.xxl * 8
        elide: Text.ElideRight
    }
    MText {
        value: root.value
        styleName: "bodyMedium"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }
}
