// Circular face. Source URL is passed in (Services/User owns ~/.face);
// Widgets never touch the filesystem. Missing image → fallback icon.
import QtQuick
import "../Commons"

Item {
    id: root

    property url source: ""
    property string fallbackIcon: "avatar-default-symbolic"
    property int size: Tokens.spacing.xxl * 2

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        id: clip
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.primaryContainer
        clip: true

        Image {
            id: face
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
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
    }
}
