// Anchored popup surface. Hosts an MCard; open/close follows
// motion.overlay (fade / zoom / fadeZoom) so bar menus match overlays.
// Opens below the parent field unless a clipped ancestor (Settings
// Flickable, window) would eat the menu — then it flips above.
// Select menus reparent onto the window so later form rows cannot
// paint through a clipped, translucent list.
import QtQuick
import QtQuick.Window
import "../Commons"

Item {
    id: root

    property bool open: false
    property int elevation: 2
    property real gap: Tokens.spacing.xs
    property bool autoPlace: true
    // Context menus have no button of their own. A click anywhere else
    // closes them, including on the window that opened the menu.
    property bool dismissAnywhere: false
    property bool opensAbove: false
    property real chromeOpacity: Chrome.washOpacity
    property bool reparentToHost: true
    default property alias content: card.content

    property Item _anchor: null

    readonly property var _host: Window.window ? Window.window.contentItem : null
    readonly property Item _field: root._anchor || root.parent

    visible: root.open || opacity > 0.01
    opacity: Motion.overlayOpacity(root.open)
    scale: Motion.overlayScale(root.open)
    transformOrigin: root.opensAbove ? Item.Bottom : Item.Top
    // Above MDialog (100): menus reparent onto the window and must
    // paint over a confirm card, not under its translucent wash.
    z: root.open && root.parent === root._host ? 200 : 0
    x: {
        if (root.parent !== root._host || !root._field || !root._host)
            return 0;
        const field = root._field;
        const host = root._host;
        const w = root.width > 0 ? root.width : root.implicitWidth;
        let raw = field.mapToItem(host, 0, 0).x;
        if (raw + w > host.width - Tokens.spacing.md)
            raw = field.mapToItem(host, field.width, 0).x - w;
        return root._clamp(raw, w, host.width);
    }
    y: {
        if (!root.autoPlace)
            return 0;
        const field = root._field;
        const h = field ? field.height : 0;
        const ly = root.opensAbove ? -(root.height + root.gap) : h + root.gap;
        if (root.parent !== root._host || !field || !root._host)
            return ly;
        const ph = root.height > 0 ? root.height : root.implicitHeight;
        return root._clamp(field.mapToItem(root._host, 0, ly).y, ph, root._host.height);
    }

    Component.onCompleted: root._syncParent()
    onOpenChanged: {
        root._syncParent();
        if (root.open)
            Qt.callLater(root._updatePlace);
    }
    onVisibleChanged: {
        if (!root.open)
            root._syncParent();
    }
    onImplicitHeightChanged: {
        if (root.open)
            root._updatePlace();
    }

    function _syncParent() {
        if (!root._anchor && root.parent && root.parent !== root._host)
            root._anchor = root.parent;
        if (!root.reparentToHost || !root._anchor)
            return;
        const stay = root.open || root.visible;
        const next = (stay && root._host) ? root._host : root._anchor;
        if (next && root.parent !== next)
            root.parent = next;
    }

    function _clipHost(): var {
        if (root.reparentToHost && root._host)
            return root._host;
        let p = root._field;
        while (p) {
            if (p.clip)
                return p;
            p = p.parent;
        }
        return root._host;
    }

    function _shouldOpenAbove(): bool {
        const field = root._field;
        const host = root._clipHost();
        if (!field || !host)
            return false;
        const h = Math.max(root.implicitHeight, Tokens.spacing.xxl * 6);
        const top = field.mapToItem(host, 0, 0).y;
        const below = host.height - top - field.height - root.gap;
        if (below >= h)
            return false;
        return (top - root.gap) > below;
    }

    function _clamp(raw: real, size: real, hostSize: real): real {
        const pad = Tokens.spacing.md;
        const max = hostSize - size - pad;
        if (max <= pad)
            return Math.max(0, (hostSize - size) / 2);
        return Math.min(Math.max(pad, raw), max);
    }

    function _updatePlace() {
        if (root.autoPlace)
            root.opensAbove = root._shouldOpenAbove();
    }

    function _inside(item: var, mx: real, my: real): bool {
        if (!item)
            return false;
        const p = item.mapFromItem(dismiss, mx, my);
        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height;
    }

    Behavior on opacity {
        enabled: Motion.overlaysFade
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }
    Behavior on scale {
        enabled: Motion.overlaysZoom
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
        }
    }

    MouseArea {
        id: dismiss
        parent: root.open && root._host ? root._host : root
        anchors.fill: parent
        enabled: root.open && root._host
        visible: enabled
        z: 190
        onPressed: (mouse) => {
            if (mouse.button !== Qt.LeftButton) {
                mouse.accepted = false;
                return;
            }
            if (root._inside(root, mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            if (!root.dismissAnywhere && root._inside(root._field, mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            root.open = false;
            mouse.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surface
        opacity: root.chromeOpacity
        z: 0
    }

    MCard {
        id: card
        anchors.fill: parent
        level: 0
        color: "transparent"
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        z: 1
    }
}
