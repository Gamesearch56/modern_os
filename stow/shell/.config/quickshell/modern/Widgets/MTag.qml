// Small status pill in a list row ("Saved", "In range"). Not clickable.
// tone "primary" stands out; "muted" reads as a quiet fact.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property string key: ""
    property var params: ({})
    property string tone: "primary"

    readonly property bool _primary: root.tone === "primary"

    visible: root.key.length > 0
    implicitHeight: Tokens.spacing.lg + Tokens.spacing.xs
    implicitWidth: label.implicitWidth + Tokens.spacing.sm * 2
    radius: Tokens.radius.full
    color: root._primary ? Colors.color.primaryContainer : Colors.color.surfaceContainerHighest
    border.width: root._primary ? 0 : Tokens.stroke.hairline
    border.color: Colors.color.outlineVariant
    Accessible.role: Accessible.StaticText
    Accessible.name: root.key.length > 0 ? I18n.t(root.key, root.params) : ""

    MText {
        id: label
        anchors.centerIn: parent
        key: root.key
        params: root.params
        styleName: "labelSmall"
        color: root._primary ? Colors.color.onPrimaryContainer : Colors.color.onSurfaceVariant
    }
}
