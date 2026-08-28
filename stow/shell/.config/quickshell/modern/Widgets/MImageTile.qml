// Image tile with a selected primary ring. Wallpaper picker and
// overview thumbnails share this so selection chrome is not copied.
import QtQuick
import "../Commons"

Item {
    id: root

    property url source: ""
    property bool selected: false

    signal clicked()

    Rectangle {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.xs
        radius: Tokens.radius.small
        color: Colors.color.surfaceContainerHighest
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Colors.color.primary : Colors.color.outlineVariant
        clip: true

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }

        Image {
            anchors.fill: parent
            source: root.source
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
