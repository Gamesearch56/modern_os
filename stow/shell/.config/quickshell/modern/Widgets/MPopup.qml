// Anchored popup surface. Hosts an MCard; open/close follows
// motion.overlay (fade / zoom / fadeZoom) so bar menus match overlays.
import QtQuick
import "../Commons"

Item {
    id: root

    property bool open: false
    property int elevation: 2
    default property alias content: card.content

    visible: root.open || opacity > 0.01
    opacity: Motion.overlayOpacity(root.open)
    scale: Motion.overlayScale(root.open)
    transformOrigin: Item.Top

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

    MCard {
        id: card
        anchors.fill: parent
        level: root.elevation
        borderWidth: popupHover.hovered ? 2 : 1
        borderColor: popupHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

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
