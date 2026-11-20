// Circular face. Source URL is passed in (Services/User owns ~/.face);
// Widgets never touch the filesystem. Missing image → fallback icon.
import QtQuick
import QtQuick.Effects
import "../Commons"

Item {
    id: root

    property url source: ""
    property string fallbackIcon: "avatar-default-symbolic"
    property string hoverIcon: ""
    property string hoverKey: ""
    property int size: Tokens.spacing.xxl * 2
    property bool ring: false

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size

    // Qt clips to the bounding rectangle, so a radius alone leaves the
    // photo square. The mask is what makes the picture a circle.
    Item {
        id: disc
        anchors.fill: parent
        anchors.margins: root.ring ? Tokens.stroke.focus : 0
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: discMask
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.color.primaryContainer
        }

        Image {
            id: face
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: status === Image.Ready
        }

        MIcon {
            visible: !face.visible
            anchors.centerIn: parent
            name: root.fallbackIcon
            size: Math.round(root.size * 0.5)
            color: Colors.color.onPrimaryContainer
            tint: true
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.color.scrim
            opacity: hoverMa.containsMouse ? Tokens.overlay.scrim : 0
            visible: root.hoverIcon.length > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.shortMs
                    easing.bezierCurve: Motion.easingStandard
                }
            }
        }

        MIcon {
            visible: root.hoverIcon.length > 0 && hoverMa.containsMouse
            anchors.centerIn: parent
            name: root.hoverIcon
            size: Math.round(root.size * 0.5)
            color: Colors.color.primary
            tint: true
        }
    }

    Item {
        id: discMask
        visible: false
        anchors.fill: disc
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
        }
    }

    Rectangle {
        visible: root.ring
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Tokens.stroke.focus
        border.color: Colors.color.primary
        antialiasing: true
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        enabled: root.hoverIcon.length > 0
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Accessible.role: root.hoverIcon.length > 0 ? Accessible.Button : Accessible.Graphic
    Accessible.name: root.hoverKey.length > 0 ? I18n.t(root.hoverKey) : ""
    Accessible.onPressAction: if (root.hoverIcon.length > 0) root.clicked()
}
