import QtQuick
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property alias text: field.text

    signal queryEdited(string text)
    signal accepted()
    signal escaped()
    signal upPressed()
    signal downPressed()

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.md + Tokens.spacing.xs * 2

    MSearchField {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Tokens.spacing.xxl + Tokens.spacing.md
        placeholderKey: "launcher.placeholder"
        escapeCloses: true
        transformOrigin: Item.Center
        scale: field.focused && Motion.overlaysZoom ? Motion.overlayFocusScale() : 1

        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }

        onTextEdited: root.queryEdited(text)
        onAccepted: root.accepted()
        onEscaped: root.escaped()
        onUpPressed: root.upPressed()
        onDownPressed: root.downPressed()
    }

    function forceActiveFocus() {
        field.forceActiveFocus();
    }
}
