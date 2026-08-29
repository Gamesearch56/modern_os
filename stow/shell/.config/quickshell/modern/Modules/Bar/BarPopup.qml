// Bar menu as a real xdg popup. Child Items inside the panel are
// clipped to bar height, which is why clock/weather/volume showed a
// one-pixel line instead of the card.
import Quickshell
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

PopupWindow {
    id: root

    property bool open: false
    property int elevation: 2
    property bool grab: true
    property int hAlign: Qt.AlignLeft
    default property alias content: card.content

    readonly property real _originX: {
        const p = root.parent;
        if (!p)
            return 0;
        if (root.hAlign === Qt.AlignRight)
            return p.width - root.width;
        if (root.hAlign === Qt.AlignHCenter)
            return (p.width - root.width) / 2;
        return 0;
    }

    color: "transparent"
    grabFocus: root.grab

    anchor.item: root.parent
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    anchor.rect.x: root._originX
    anchor.rect.y: (root.parent ? root.parent.height : 0) + Tokens.spacing.sm
    anchor.rect.width: 1
    anchor.rect.height: 1

    onOpenChanged: {
        if (root.visible !== root.open)
            root.visible = root.open;
        if (root.open) {
            root.anchor.updateAnchor();
            Popups.opened();
        } else {
            Popups.closed();
        }
    }

    onVisibleChanged: {
        if (root.open !== root.visible)
            root.open = root.visible;
    }

    Connections {
        target: Popups
        function onCloseRequested() {
            root.open = false;
        }
    }

    MCard {
        id: card
        anchors.fill: parent
        level: root.elevation
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
        borderWidth: Tokens.stroke.hairline
        borderColor: popupHover.hovered ? Colors.color.primary : Colors.color.outlineVariant
        scale: Motion.overlayScale(root.open)
        transformOrigin: Item.Top

        HoverHandler {
            id: popupHover
        }

        Behavior on borderColor {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
        Behavior on scale {
            enabled: Motion.overlayZooms()
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }
    }
}
