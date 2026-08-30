// Image tile. Keyboard `current` and pointer hover share a primary
// ring drawn above the photo. MultiEffect masks the bitmap to the same
// radius as the hover ring — Rectangle.clip is axis-aligned.
import QtQuick
import QtQuick.Effects
import "../Commons"

Item {
    id: root

    property url source: ""
    property bool selected: false
    property bool current: false

    readonly property bool _ring: root.current || ma.containsMouse
    readonly property real _radius: Tokens.radius.small

    signal clicked()
    signal hovered()

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root._radius
        color: Colors.color.surfaceContainerHighest
    }

    Item {
        id: contents
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

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

    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: root._radius
            color: Qt.rgba(1, 1, 1, 1)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: contents
        maskEnabled: true
        maskSource: roundMask
    }

    Rectangle {
        anchors.fill: parent
        radius: root._radius
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
        radius: root._radius
        active: root._ring
    }
}
