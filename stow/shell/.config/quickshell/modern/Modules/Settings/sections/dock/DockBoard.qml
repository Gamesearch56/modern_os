// Pointer mapping for the dock field. A drag from the app grid adds a
// pin; a drag inside the field reorders it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell.Hyprland
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    property var pins: []
    property var installed: []

    property string _dragId: ""
    property int _dragFrom: -1
    property int _hover: -1

    spacing: Tokens.spacing.lg
    Layout.fillWidth: true

    property real _flickY: 0

    function _lockFlick(lock: bool) {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined) {
                if (lock)
                    root._flickY = p.contentY;
                p.interactive = !lock;
                if (!lock)
                    p.contentY = root._flickY;
                return;
            }
            p = p.parent;
        }
    }

    // The launcher window starts at the screen corner, so a local pointer
    // plus that corner is the cursor. This window floats: mapToGlobal
    // stays inside it (origin 0,0) until the client snapshot's `at` is
    // added. That snapshot is empty until a refresh.
    function _pair(at: var): var {
        if (at === undefined || at === null)
            return null;
        if (at.x !== undefined && at.y !== undefined) {
            const px = Number(at.x);
            const py = Number(at.y);
            if (!Number.isNaN(px) && !Number.isNaN(py))
                return Qt.point(px, py);
        }
        // A QVariantList has no reliable length. Do not index a string:
        // "760"[0] is "7".
        if (typeof at !== "string" && at[1] !== undefined && at[1] !== null) {
            const ax = Number(at[0]);
            const ay = Number(at[1]);
            if (!Number.isNaN(ax) && !Number.isNaN(ay))
                return Qt.point(ax, ay);
        }
        const parts = String(at).replace(/[\[\]]/g, " ").split(/[,\s]+/);
        if (parts.length < 2)
            return null;
        const x = Number(parts[0]);
        const y = Number(parts[1]);
        if (Number.isNaN(x) || Number.isNaN(y))
            return null;
        return Qt.point(x, y);
    }

    function windowAt(): var {
        const list = Hyprland.toplevels && Hyprland.toplevels.values ? Hyprland.toplevels.values : [];
        let found = null;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ipc = t.lastIpcObject || ({});
            const title = String(t.title || ipc.title || "");
            if (title.indexOf("modern.settings") < 0)
                continue;
            const pt = root._pair(ipc.at);
            if (!pt)
                continue;
            if (t.activated)
                return pt;
            found = pt;
        }
        return found;
    }

    function toScreen(gx: real, gy: real): var {
        const win = Window.window;
        const at = root.windowAt();
        if (!win || !win.contentItem || !at)
            return null;
        const origin = win.contentItem.mapToGlobal(0, 0);
        return Qt.point(Math.round(gx - origin.x + at.x), Math.round(gy - origin.y + at.y));
    }

    // mapToGlobal's absolute value is not the pointer on this floating
    // window. The point inside the window content, plus the window's
    // compositor position, is.
    function _pointer(item: var, lx: real, ly: real, gx: real, gy: real): var {
        const at = root.windowAt();
        const win = Window.window;
        if (at && win && win.contentItem && item) {
            const p = item.mapToItem(win.contentItem, lx, ly);
            return Qt.point(Math.round(at.x + p.x), Math.round(at.y + p.y));
        }
        return root.toScreen(gx, gy);
    }

    function _follow(gx: real, gy: real, item: var, lx: real, ly: real) {
        const s = root._pointer(item, lx, ly, gx, gy);
        if (!s) {
            Hypr.refreshToplevels();
            return;
        }
        // fromDock stays false so a settings drag does not raise the
        // on-screen trash. The ghost is the same one the launcher uses.
        if (!Dock.dragActive)
            Dock.beginDrag(root._dragId, false, root._dragFrom, s.x, s.y);
        else
            Dock.moveDrag(s.x, s.y);
    }

    Component.onCompleted: Hypr.refreshToplevels()

    Timer {
        // The window is not in the client list on the first frame.
        interval: Motion.extraLongMs
        running: true
        repeat: false
        onTriggered: {
            if (!root.windowAt())
                Hypr.refreshToplevels();
        }
    }

    function begin(id: string, from: int, gx: real, gy: real, item: var, lx: real, ly: real) {
        root._dragId = id;
        root._dragFrom = from;
        root._lockFlick(true);
        root._follow(gx, gy, item, lx, ly);
        root._hover = strip.indexAtGlobal(gx, gy);
    }

    function move(gx: real, gy: real, item: var, lx: real, ly: real) {
        if (!root._dragId.length)
            return;
        root._follow(gx, gy, item, lx, ly);
        root._hover = strip.indexAtGlobal(gx, gy);
    }

    function end(gx: real, gy: real) {
        const id = root._dragId;
        const from = root._dragFrom;
        const to = strip.indexAtGlobal(gx, gy);
        if (id.length && to >= 0) {
            Dock.cancel();
            root._clear();
            if (from >= 0)
                Dock.move(from, to);
            else
                Dock.insertAt(id, to);
            return;
        }
        root._clear();
        Dock.finish();
    }

    function _clear() {
        root._dragId = "";
        root._dragFrom = -1;
        root._hover = -1;
        root._lockFlick(false);
    }

    function cancel() {
        root._clear();
        Dock.cancel();
    }

    MSectionHeader {
        key: "settings.dock.pins"
        topMargin: Tokens.spacing.lg
    }

    DockStrip {
        id: strip
        Layout.fillWidth: true
        board: root
        pins: root.pins
    }

    DockApps {
        Layout.fillWidth: true
        board: root
        installed: root.installed
    }
}
