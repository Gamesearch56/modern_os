// The file view and the margin already around it are the selection
// zone. A drag on that empty space draws a box. The press stays
// behind the rows, so a click on a file still selects or drags that
// file. The box never starts a move, and the selection is not an undo step.
import QtQuick
import QtQuick.Window
import "../../Commons"
import "../../Services"

MouseArea {
    id: root

    property Flickable flick: null
    property bool live: true
    property Repeater repeater: null
    signal menu(real x, real y)

    property bool _dragged: false
    property bool _box: false
    property bool _extra: false
    property var _base: []
    property real _x0: 0
    property real _y0: 0
    property real _x1: 0
    property real _y1: 0

    // Parent view, not an inset. contentHeight covers the scrollable
    // parent; the viewport height covers the empty space under a short list.
    width: root.flick ? root.flick.width : (parent ? parent.width : 0)
    height: root.flick ? Math.max(root.flick.contentHeight, root.flick.height) : (parent ? parent.height : 0)
    enabled: root.live && !Files.covered && !FilesDrag.active && !Files.propertiesOpen && !Files.naming && !Files.confirming && !FilesConflict.open
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true
    focus: true
    z: -1
    onEnabledChanged: if (!enabled) root._end(true)

    onPressed: (mouse) => {
        forceActiveFocus();
        root._dragged = false;
        root._extra = (mouse.modifiers & Qt.ControlModifier) !== 0;
        root._base = root._extra ? (Files.selected || []).slice() : [];
        root._x0 = mouse.x;
        root._y0 = mouse.y;
        root._x1 = mouse.x;
        root._y1 = mouse.y;
    }
    onPositionChanged: (mouse) => {
        if ((mouse.buttons & Qt.LeftButton) === 0)
            return;
        root._x1 = mouse.x;
        root._y1 = mouse.y;
        const dx = root._x1 - root._x0;
        const dy = root._y1 - root._y0;
        if (!root._dragged && (dx * dx + dy * dy) < Tokens.spacing.sm * Tokens.spacing.sm)
            return;
        root._dragged = true;
        root._box = true;
        FilesSelect.banding = true;
        root._apply();
    }
    onReleased: root._end(false)
    onCanceled: root._end(true)
    onClicked: (mouse) => {
        if (root._dragged || Files._holdSelect)
            return;
        Files.clearSelection();
        if (mouse.button !== Qt.RightButton)
            return;
        const host = Window.window ? Window.window.contentItem : root;
        const at = mapToItem(host, mouse.x, mouse.y);
        root.menu(at.x, at.y);
    }

    // Above the rows, but it must not take the click that belongs to a file.
    Rectangle {
        parent: root.parent
        z: 2
        enabled: false
        visible: root._box
        // Stay inside this zone, including the margin, and off the sidebar.
        x: Math.max(root.x, root.x + Math.min(root._x0, root._x1))
        y: Math.max(root.y, root.y + Math.min(root._y0, root._y1))
        width: Math.max(0, Math.min(root.x + root.width, root.x + Math.max(root._x0, root._x1)) - x)
        height: Math.max(0, Math.min(root.y + root.height, root.y + Math.max(root._y0, root._y1)) - y)
        radius: Tokens.radius.small
        color: Colors.color.primary
        opacity: Tokens.interaction.band
        border.width: Tokens.stroke.focus
        border.color: Colors.color.primary
    }

    // Clicked follows released. Drop the gesture after that click.
    function _end(now: bool) {
        if (!now && root._dragged)
            root._apply();
        root._box = false;
        FilesSelect.banding = false;
        if (now)
            root._dragged = false;
        else
            Qt.callLater(() => { root._dragged = false; });
    }

    function _apply() {
        const x = Math.min(root._x0, root._x1);
        const y = Math.min(root._y0, root._y1);
        const w = Math.abs(root._x1 - root._x0);
        const h = Math.abs(root._y1 - root._y0);
        const hits = root._hits(x, y, w, h);
        const next = root._base.slice();
        for (let i = 0; i < hits.length; i++) {
            if (next.indexOf(hits[i]) < 0)
                next.push(hits[i]);
        }
        if (!root._same(Files.selected || [], next))
            Files.selected = next;
        if (hits.length)
            FilesSelect.anchor = hits[hits.length - 1];
    }

    function _hits(x, y, w, h) {
        const rep = root.repeater;
        const hits = [];
        if (!rep)
            return hits;
        const right = x + w;
        const bottom = y + h;
        for (let i = 0; i < rep.count; i++) {
            const item = rep.itemAt(i);
            if (!item || item.width < 1 || !item.modelData)
                continue;
            const row = item.modelData;
            if (row.readable === false || row.canRead === false)
                continue;
            const id = String(row.path || row.uri || "");
            if (!id)
                continue;
            const p = item.mapToItem(root, 0, 0);
            if (p.x < right && p.x + item.width > x && p.y < bottom && p.y + item.height > y)
                hits.push(id);
        }
        return hits;
    }

    function _same(a: var, b: var): bool {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }
}
