import QtQuick
import "../../Commons"
import "../../Widgets"

// A short message over the video after a change you cannot see: volume,
// speed, a seek, a track. It fades by itself and never takes a click.
Rectangle {
    id: root

    property string message: ""
    property bool _up: false

    function show(text: string) {
        root.message = text;
        root._up = true;
        hold.restart();
    }

    implicitWidth: label.implicitWidth + Tokens.spacing.lg * 2
    implicitHeight: label.implicitHeight + Tokens.spacing.sm * 2
    radius: Tokens.radius.full
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    opacity: root._up ? 1 : 0
    visible: opacity > 0

    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.message

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.shortMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easingStandard
        }
    }

    MText {
        id: label
        anchors.centerIn: parent
        value: root.message
        styleName: "labelLarge"
        color: Colors.color.onSurface
    }

    Timer {
        id: hold
        interval: Motion.playerOsdMs
        onTriggered: root._up = false
    }
}
