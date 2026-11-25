import Quickshell
import QtQuick
import "../Commons"

// Where a dock drag is on the compositor's screen space. Owned by Dock,
// which forwards the calls the modules use.

QtObject {
    id: root

    function screenOrigin(screen: var): point {
        const mon = screen ? Hypr.monitorForScreen(screen) : null;
        const ipc = mon && mon.lastIpcObject ? mon.lastIpcObject : null;
        if (ipc && ipc.x !== undefined && ipc.y !== undefined)
            return Qt.point(Number(ipc.x), Number(ipc.y));
        return Qt.point(screen ? (screen.virtualX || 0) : 0, screen ? (screen.virtualY || 0) : 0);
    }

    // A layer-shell window does not learn its place on the screen, so
    // mapToGlobal stays inside the window. The edge and margins rebuild
    // the compositor position the pointer events are missing.
    function layerToScreen(screen: var, edge: string, ml: real, mt: real, mr: real, mb: real, ww: real, wh: real, lx: real, ly: real): point {
        const o = root.screenOrigin(screen);
        const sw = screen ? screen.width : 0;
        const sh = screen ? screen.height : 0;
        let x = o.x + ml + lx;
        let y = o.y + mt + ly;
        if (edge === "bottom")
            y = o.y + Math.max(0, sh - mb - wh) + ly;
        else if (edge === "right")
            x = o.x + Math.max(0, sw - mr - ww) + lx;
        return Qt.point(x, y);
    }

    function _screenByName(name: string): var {
        const screens = Quickshell.screens;
        const key = String(name || "");
        for (let i = 0; i < screens.length; i++) {
            if (String(screens[i].name || "") === key)
                return screens[i];
        }
        return null;
    }

    // Items live under the backing window, which has no screen. The dock
    // row carries the output name. Without it a bottom strip is drawn at y=0.
    function _panelScreen(item: var): var {
        let node = item;
        while (node) {
            const named = node.screenName ? root._screenByName(node.screenName) : null;
            if (named)
                return named;
            if (node.screen && Number(node.screen.height) > 0)
                return node.screen;
            node = node.parent;
        }
        return null;
    }

    function pointerToScreen(item: var, edge: string, gx: real, gy: real): point {
        const win = item && item.Window ? item.Window.window : null;
        if (!win || !win.contentItem)
            return Qt.point(gx, gy);
        const zero = win.contentItem.mapToGlobal(0, 0);
        const m = win.margins;
        const strip = DockLayout.cross;
        return root.layerToScreen(root._panelScreen(item), edge,
            m ? Number(m.left) || 0 : 0, m ? Number(m.top) || 0 : 0,
            m ? Number(m.right) || 0 : 0, m ? Number(m.bottom) || 0 : 0,
            Number(win.width) || strip, Number(win.height) || strip,
            gx - zero.x, gy - zero.y);
    }

    function screenAt(x: real, y: real): var {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            const o = root.screenOrigin(s);
            if (x >= o.x && y >= o.y && x < o.x + s.width && y < o.y + s.height)
                return s;
        }
        return screens.length ? screens[0] : null;
    }
}
