// Determinate track or an indeterminate pulse. Token colors only.
// `enclosureRadius` paints this bar as the bottom slice of a taller
// rounded rect so a toast can flush the bar to the card edge without
// square corners leaking past the banner radius (Item.clip is axis-aligned).
import QtQuick
import "../Commons"

Item {
    id: root

    property real value: 0
    property bool indeterminate: false
    property real radius: Tokens.radius.full
    property real enclosureRadius: 0
    property real enclosureHeight: 0

    readonly property bool _enclose: root.enclosureRadius > 0 && root.enclosureHeight > root.height
    readonly property real _bodyH: root._enclose ? root.enclosureHeight : height
    readonly property real _bodyR: root._enclose ? root.enclosureRadius : root.radius

    implicitWidth: Tokens.spacing.xxl * 10
    implicitHeight: Tokens.spacing.sm
    clip: true

    Rectangle {
        id: track
        width: parent.width
        height: root._bodyH
        y: parent.height - height
        radius: root._bodyR
        color: Colors.color.surfaceContainerHighest
        antialiasing: true
    }

    Item {
        id: fillClip
        width: root.indeterminate
            ? parent.width
            : parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        clip: true

        Rectangle {
            id: fill
            width: root._enclose ? root.width : fillClip.width
            height: root._bodyH
            y: fillClip.height - height
            radius: root._bodyR
            color: Colors.color.primary
            opacity: root.indeterminate ? pulse.opacity : 1
            antialiasing: true
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
