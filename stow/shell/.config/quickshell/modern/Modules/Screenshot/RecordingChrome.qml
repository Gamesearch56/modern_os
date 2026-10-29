import QtQuick
import "../../Commons"

// Shared stop / hint card. Opacity and scale are GPU-cheap; the
// layer window stays mounted so a thin edge can bring this back.
Rectangle {
    id: root

    required property bool open
    property int origin: Item.Top

    color: "transparent"
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    opacity: root.open ? 1 : 0

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.color.surface
        opacity: Chrome.washOpacity
        z: -1
    }
    scale: Motion.overlayScale(root.open)
    transformOrigin: root.origin

    MouseArea {
        anchors.fill: parent
        enabled: root.open
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }
    Behavior on scale {
        enabled: Motion.overlaysZoom
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }
}
