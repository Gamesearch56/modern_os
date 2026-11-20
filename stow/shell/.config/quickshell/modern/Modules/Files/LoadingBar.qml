// Indeterminate bar. The window shows it only after a listing or a
// search has already been running for a while.
import QtQuick
import "../../Commons"

Item {
    id: root

    property bool active: false

    visible: active
    // The bead travels in from the left. Without a clip it paints across
    // the sidebar and the rest of the window. A hidden bar keeps no height,
    // so the folder grid returns to the breadcrumb.
    clip: true
    height: active ? Tokens.spacing.xs : 0
    Accessible.role: Accessible.Indicator
    Accessible.name: I18n.t("files.loading")

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
    }

    Rectangle {
        id: bead
        width: Tokens.spacing.xxl * 8
        height: parent.height
        radius: Tokens.radius.full
        color: Colors.color.primary
        visible: root.active

        SequentialAnimation on x {
            running: root.active && root.width > bead.width
            loops: Animation.Infinite
            NumberAnimation {
                from: -bead.width
                to: root.width
                duration: Motion.extraLongMs
            }
        }
    }
}
