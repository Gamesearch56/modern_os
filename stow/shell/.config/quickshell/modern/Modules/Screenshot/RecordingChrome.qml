import QtQuick
import "../../Commons"

// Shared stop / hint card. Opacity and scale are GPU-cheap; the
// layer window stays mounted so a thin edge can bring this back.
Rectangle {
    id: root

    required property bool open
    property int origin: Item.Top

    color: Colors.color.surface
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    opacity: root.open ? (Config.design.transparency ?? 0.85) : 0
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
