// Determinate track or an indeterminate pulse. Token colors only.
import QtQuick
import "../Commons"

Item {
    id: root

    property real value: 0
    property bool indeterminate: false

    implicitWidth: Tokens.spacing.xxl * 10
    implicitHeight: Tokens.spacing.sm
    clip: true

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest

        Rectangle {
            id: fill
            width: root.indeterminate
                ? parent.width
                : parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: Colors.color.primary
            opacity: root.indeterminate ? pulse.opacity : 1
        }
    }

    SequentialAnimation {
        id: pulse
        property real opacity: 1
        running: root.indeterminate && root.visible
        loops: Animation.Infinite
        NumberAnimation {
            target: pulse
            property: "opacity"
            from: 0.35
            to: 1
            duration: Motion.mediumMs
            easing.bezierCurve: Motion.easingStandard
        }
        NumberAnimation {
            target: pulse
            property: "opacity"
            from: 1
            to: 0.35
            duration: Motion.mediumMs
            easing.bezierCurve: Motion.easingStandard
        }
    }
}
