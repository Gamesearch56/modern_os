// Small elevated label by an icon button. Position is applied while the
// card is still invisible, so a reparent never flashes at the window
// origin before it sits beside the button.
import QtQuick
import QtQuick.Window
import "../Commons"

Item {
    id: root

    property bool open: false
    property string key: ""
    property string value: ""
    property Item anchor: null
    // "bottom" under the control; "right" to its trailing edge.
    property string edge: "bottom"

    readonly property bool shown: root.open && (root.key.length > 0 || root.value.length > 0)
    readonly property Item _anchor: root.anchor || root.parent
    readonly property var _host: Window.window ? Window.window.contentItem : null
    readonly property real _limit: Tokens.spacing.xxl * 8

    width: 0
    height: 0
    visible: false

    onShownChanged: root._sync()

    MCard {
        id: card
        property bool fade: true
        level: 2
        padding: Tokens.spacing.sm
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        visible: opacity > 0
        opacity: 0
        z: 240
        width: label.width + padding * 2
        height: label.implicitHeight + padding * 2

        Behavior on opacity {
            enabled: card.fade && Motion.overlaysFade
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }

        MText {
            id: label
            width: Math.min(implicitWidth, root._limit - card.padding * 2)
            key: root.key
            value: root.value
            styleName: "labelMedium"
            elide: Text.ElideNone
            wrapMode: Text.NoWrap
            onImplicitWidthChanged: if (root.shown) root._sync()
        }
    }

    function _sync() {
        const anchor = root._anchor;
        const host = root._host;
        if (!root.shown || !anchor || !host || label.implicitWidth <= 0) {
            card.fade = true;
            card.opacity = 0;
            return;
        }
        const origin = anchor.mapToItem(host, 0, 0);
        const pad = Tokens.spacing.sm;
        const gap = Tokens.spacing.xs;
        const w = label.width + card.padding * 2;
        const h = label.implicitHeight + card.padding * 2;
        let x = 0;
        let y = 0;
        if (root.edge === "right") {
            x = origin.x + anchor.width + gap;
            if (x + w > host.width - pad)
                x = Math.max(pad, origin.x - w - gap);
            y = origin.y + (anchor.height - h) / 2;
            y = Math.max(pad, Math.min(y, host.height - h - pad));
        } else {
            x = origin.x + (anchor.width - w) / 2;
            x = Math.max(pad, Math.min(x, host.width - w - pad));
            y = origin.y + anchor.height + gap;
            if (y + h > host.height - pad)
                y = Math.max(pad, origin.y - h - gap);
        }
        card.parent = host;
        card.x = x;
        card.y = y;
        if (card.opacity > 0)
            return;
        card.fade = false;
        card.opacity = 0;
        card.fade = true;
        card.opacity = 1;
    }
}
