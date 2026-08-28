// Window header: title + visible close (error) for FloatingWindow chrome.
import QtQuick
import QtQuick.Layouts
import "../Commons"

RowLayout {
    id: root

    property string titleKey: ""
    property string titleValue: ""
    property string actionKey: ""
    property string actionIcon: ""

    signal closed()
    signal actionClicked()

    Layout.fillWidth: true
    spacing: Tokens.spacing.md

    MText {
        key: root.titleKey
        value: root.titleValue
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MIconButton {
        visible: root.actionKey.length > 0 || root.actionIcon.length > 0
        iconName: root.actionIcon.length > 0 ? root.actionIcon : "list-add"
        key: root.actionKey
        onClicked: root.actionClicked()
    }

    MIconButton {
        close: true
        iconName: "window-close"
        onClicked: root.closed()
    }
}
