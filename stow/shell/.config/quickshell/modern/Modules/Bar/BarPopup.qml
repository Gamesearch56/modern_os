// Bar menu as a real xdg popup. Child Items inside the panel are
// clipped to bar height, which is why clock/weather/volume showed a
// one-pixel line instead of the card. PopupWindow has no visual
// parent, so callers pass the island/button as `anchorItem`.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

PopupWindow {
    id: root

    property bool open: false
    property int elevation: 0
    property bool grab: false
    property int hAlign: Qt.AlignLeft
    property Item anchorItem: null
    property bool hoverBridge: false
    property bool bodyHovered: false
    property bool barIslandChrome: false
    default property alias content: card.content

    signal grabReady()

    readonly property real _popupW: root.implicitWidth
    readonly property real _gap: Tokens.spacing.sm
    readonly property real _originX: {
        const p = root.anchorItem;
        if (!p)
            return 0;
        if (root.hAlign === Qt.AlignRight)
            return p.width - root._popupW;
        if (root.hAlign === Qt.AlignHCenter)
            return (p.width - root._popupW) / 2;
        return 0;
    }

    visible: false
    color: "transparent"
    grabFocus: root.open && !root.hoverBridge

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    anchor.rect.x: root._originX
    anchor.rect.y: (root.anchorItem ? root.anchorItem.height : 0) + (root.hoverBridge ? 0 : root._gap)
    anchor.rect.width: 1
    anchor.rect.height: 1

    onOpenChanged: {
        if (root.visible !== root.open)
            root.visible = root.open;
        if (root.open) {
            root.anchor.updateAnchor();
            Popups.opened(root);
            if (!root.hoverBridge) {
                Qt.callLater(() => {
                    if (!root.open)
                        return;
                    keyGrab.active = true;
                    root.grabReady();
                });
            }
        } else {
            root.bodyHovered = false;
            keyGrab.active = false;
            Popups.closed(root);
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
        function onExclusive(keeper) {
            if (root !== keeper && root.open)
                root.open = false;
        }
    }

    HyprlandFocusGrab {
        id: keyGrab
        windows: [root]
        onCleared: {
            if (root.open)
                root.open = false;
        }
        onActiveChanged: {
            if (keyGrab.active)
                root.grabReady();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open && !root.hoverBridge
        context: Qt.ApplicationShortcut
        onActivated: root.open = false
    }

    Item {
        id: inner
        anchors.fill: parent

        Item {
            id: bridge
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.hoverBridge ? root._gap : 0

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                HoverHandler {
                    id: bridgeHover
                    enabled: root.hoverBridge
                    onHoveredChanged: root.bodyHovered = hovered || cardHover.hovered
                }
            }
        }

        MCard {
            id: card
            anchors.top: bridge.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            level: root.elevation
            color: Colors.color.surface
            radius: root.barIslandChrome ? Tokens.radius.full : Tokens.radius.medium
            opacity: Config.design.transparency ?? 0.85
            borderWidth: root.barIslandChrome ? Tokens.stroke.hairline : (root.open ? Tokens.stroke.focus : Tokens.stroke.hairline)
            borderColor: root.barIslandChrome ? Colors.color.outlineVariant : (root.open ? Colors.color.primary : Colors.color.outlineVariant)
            scale: Motion.overlayScale(root.open)
            transformOrigin: Item.Top

            HoverHandler {
                id: cardHover
                onHoveredChanged: root.bodyHovered = hovered || bridgeHover.hovered
            }

            Behavior on scale {
                enabled: Motion.overlaysZoom
                NumberAnimation {
                    duration: Motion.mediumMs
                    easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
                }
            }
        }
    }
}
