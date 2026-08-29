// Image tile. Keyboard `current` and pointer hover share a primary
// ring drawn above the photo (a plate border sits under the Image).
import QtQuick
import "../Commons"

Item {
    id: root

    property url source: ""
    property bool selected: false
    property bool current: false

    readonly property bool _ring: root.current || ma.containsMouse

    signal clicked()
    signal hovered()

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Colors.color.surfaceContainerHighest
        clip: true
        layer.enabled: true

        Image {
            anchors.fill: parent
            source: root.source
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.color.primary
            opacity: root.selected ? Tokens.interaction.focus : 0
        }

        Rectangle {
            visible: root.selected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.xs
            width: Tokens.spacing.xl
            height: Tokens.spacing.xl
            radius: Tokens.radius.full
            color: Colors.color.primary

            MIcon {
                anchors.centerIn: parent
                name: "object-select-symbolic"
                size: Tokens.icon.sm
                color: Colors.color.onPrimary
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: "transparent"
        border.width: root._ring ? 0 : Tokens.stroke.hairline
        border.color: Colors.color.outlineVariant
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onEntered: root.hovered()
    }

    MFocusRing {
        radius: Tokens.radius.small
        active: root._ring
    }
}
