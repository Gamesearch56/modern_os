// Bar menu on the same layer-shell host as the Super+N control panel
// so Hyprland's quickshell-blur and the surface wash match. PopupWindow
// (BarPopup) stays for hover pills — those must not claim focus.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

PanelWindow {
    id: root

    property bool open: false
    property int elevation: 0
    property int hAlign: Qt.AlignLeft
    property Item anchorItem: null
    property var barScreen: null
    property real padding: Tokens.spacing.md
    property real panelWidth: Tokens.spacing.xxl * 14
    property real panelHeight: Tokens.spacing.xxl * 12
    default property alias content: card.content

    signal grabReady()

    readonly property real _gap: Config.bar.endGap ?? Tokens.spacing.md
    readonly property bool _barBottom: Config.bar.position === "bottom"
    readonly property bool _barLeft: Config.bar.position === "left"
    readonly property bool _barRight: Config.bar.position === "right"
    readonly property bool _side: root._barLeft || root._barRight

    visible: root.open
    screen: root.barScreen
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay

    function _anchorLocal() {
        const p = root.anchorItem;
        if (!p)
            return Qt.point(root._gap, root._gap);
        const g = p.mapToGlobal(0, 0);
        const o = chrome.mapToGlobal(0, 0);
        return Qt.point(g.x - o.x, g.y - o.y);
    }

    function _cardX(): real {
        const w = root.panelWidth;
        const maxX = Math.max(root._gap, chrome.width - w - root._gap);
        if (root._barLeft)
            return root._gap;
        if (root._barRight)
            return maxX;
        const p = root.anchorItem;
        if (!p)
            return root._gap;
        const loc = root._anchorLocal();
        let x = loc.x;
        if (root.hAlign === Qt.AlignRight)
            x = loc.x + p.width - w;
        else if (root.hAlign === Qt.AlignHCenter)
            x = loc.x + (p.width - w) / 2;
        return Math.max(root._gap, Math.min(x, maxX));
    }

    function _cardY(): real {
        const h = root.panelHeight;
        if (root._barBottom)
            return chrome.height - h;
        if (!root._side)
            return 0;
        const p = root.anchorItem;
        if (!p)
            return root._gap;
        const y = root._anchorLocal().y;
        return Math.max(root._gap, Math.min(y, chrome.height - h - root._gap));
    }

    onOpenChanged: {
        if (root.open) {
            Popups.opened(root);
            Qt.callLater(() => {
                if (!root.open)
                    return;
                keyGrab.active = true;
                root.grabReady();
            });
        } else {
            keyGrab.active = false;
            Popups.closed(root);
        }
    }

    Item {
        id: overlay
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            onClicked: root.open = false
        }

        Item {
            id: chrome
            anchors.fill: parent
            anchors.topMargin: Config.bar.position === "top" ? BarLayout.windowInset : 0
            anchors.bottomMargin: Config.bar.position === "bottom" ? BarLayout.windowInset : 0
            anchors.leftMargin: Config.bar.position === "left" ? BarLayout.windowInset : 0
            anchors.rightMargin: Config.bar.position === "right" ? BarLayout.windowInset : 0

            MPanelSurface {
                id: host
            x: {
                void root.open;
                void chrome.width;
                void root.panelWidth;
                void root.hAlign;
                return root._cardX();
            }
            y: {
                void root.open;
                void chrome.height;
                void root.panelHeight;
                return root._cardY();
            }
            width: root.panelWidth
            height: root.panelHeight
            scale: Motion.overlayScale(root.open)
            transformOrigin: root._barBottom ? Item.Bottom : Item.Top

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            MCard {
                id: card
                anchors.fill: parent
                level: root.elevation
                padding: root.padding
                color: "transparent"
                radius: Tokens.radius.medium
                borderWidth: 0
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

    HyprlandFocusGrab {
        id: keyGrab
        windows: Popups.grabWindows(root, root.screen)
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
        context: Qt.ApplicationShortcut
        enabled: root.open
        onActivated: root.open = false
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
}
