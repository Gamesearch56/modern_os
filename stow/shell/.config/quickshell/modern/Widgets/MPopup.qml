// Anchored popup surface. Hosts an MCard; open/close follows
// motion.overlay (fade / zoom / fadeZoom) so bar menus match overlays.
import QtQuick
import QtQuick.Window
import "../Commons"

Item {
    id: root

    property bool open: false
    property int elevation: 2
    default property alias content: card.content

    readonly property var _host: Window.window ? Window.window.contentItem : null

    visible: root.open || opacity > 0.01
    opacity: Motion.overlayOpacity(root.open)
    scale: Motion.overlayScale(root.open)
    transformOrigin: Item.Top

    function _inside(item: var, mx: real, my: real): bool {
        if (!item)
            return false;
        const p = item.mapFromItem(dismiss, mx, my);
        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height;
    }

    Behavior on opacity {
        enabled: Motion.overlayFades()
        NumberAnimation {
            duration: Motion.medium()
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }
    Behavior on scale {
        enabled: Motion.overlayZooms()
        NumberAnimation {
            duration: Motion.medium()
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }

    MouseArea {
        id: dismiss
        parent: root.open && root._host ? root._host : root
        anchors.fill: parent
        enabled: root.open && root._host
        visible: enabled
        z: 40
        onPressed: (mouse) => {
            if (root._inside(root, mouse.x, mouse.y) || root._inside(root.parent, mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            root.open = false;
            mouse.accepted = false;
        }
    }

    MCard {
        id: card
        anchors.fill: parent
        level: 0
        color: Colors.color.surfaceContainerHighest
        borderWidth: popupHover.hovered ? 2 : 1
        borderColor: popupHover.hovered ? Colors.color.primary : Colors.color.outlineVariant
        z: 1

        HoverHandler {
            id: popupHover
        }

        Behavior on borderColor {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }
}
