// Section title plus optional hint. Used in Settings bodies, the
// cheatsheet, and grouped nav — not a clickable row.
import QtQuick
import QtQuick.Layouts
import "../Commons"

ColumnLayout {
    id: root

    property string key: ""
    property string value: ""
    property string hintKey: ""
    property string hintValue: ""
    property string styleName: "titleSmall"
    property bool caps: false
    property real topMargin: Tokens.spacing.md

    spacing: Tokens.spacing.xs
    Layout.fillWidth: true

    MText {
        key: root.key
        value: root.value
        styleName: root.styleName
        color: Colors.color.onSurfaceVariant
        font.capitalization: root.caps ? Font.AllUppercase : Font.MixedCase
        Layout.fillWidth: true
        Layout.topMargin: root.topMargin
    }

    MHint {
        visible: root.hintKey.length > 0 || root.hintValue.length > 0
        key: root.hintKey
        value: root.hintValue
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.sm
    }
}
