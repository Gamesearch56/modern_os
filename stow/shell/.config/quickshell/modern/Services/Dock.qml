pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Pinned applications and the in-progress drag. The module paints the
// dock; only this service writes dock.apps.

Singleton {
    id: root

    property bool dragActive: false
    property string dragId: ""
    property bool dragFromDock: false
    property int dragIndex: -1
    property real dragX: 0
    property real dragY: 0
    property string hoverKind: ""
    property int hoverIndex: -1
    property string hoverScreen: ""
    property string dragScreen: ""

    function apps(): var {
        void Config.generation;
        const raw = Config.dock ? Config.dock.apps : [];
        const list = raw || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const id = String(list[i] || "");
            if (id.length)
                out.push(id);
        }
        return out;
    }

    function labelFor(id: string): string {
        if (id === "shell:settings")
            return I18n.t("settings.title");
        if (id === "shell:store")
            return I18n.t("store.title");
        if (id === "shell:files")
            return I18n.t("files.launcherName");
        return Apps.labelForId(id);
    }

    function iconFor(id: string): string {
        const mark = SystemIcons.glyph(id);
        if (mark.length)
            return mark;
        return Apps.iconForId(id);
    }

    function launch(id: string) {
        const key = String(id || "");
        if (!key.length)
            return;
        if (key === "shell:settings") {
            Settings.show();
            Launcher.hide();
            return;
        }
        if (key === "shell:store") {
            Store.show();
            Launcher.hide();
            return;
        }
        if (key === "shell:files") {
            Files.show("");
            Launcher.hide();
            return;
        }
        Launcher.record(key);
        // Mail, calendar, and WhatsApp stay on the background workspace.
        // gtk-launch activates that window and leaves it there.
        const entry = Apps._entryById(key);
        if (!Hypr.raiseDesktopOrLaunch(key, entry))
            Apps.launchId(key);
        Launcher.hide();
    }

    function _save(list: var) {
        ConfigWrite.set("dock.apps", list);
    }

    function removeAt(index: int) {
        const list = root.apps();
        if (index < 0 || index >= list.length)
            return;
        list.splice(index, 1);
        root._save(list);
    }

    function move(from: int, to: int) {
        const list = root.apps();
        if (from < 0 || from >= list.length)
            return;
        let dest = to;
        if (dest < 0)
            dest = list.length;
        if (dest > from)
            dest -= 1;
        if (dest === from)
            return;
        const id = list.splice(from, 1)[0];
        if (dest > list.length)
            dest = list.length;
        list.splice(dest, 0, id);
        root._save(list);
    }

    function insertAt(id: string, index: int) {
        const key = String(id || "");
        if (!key.length)
            return;
        const list = root.apps();
        const existing = list.indexOf(key);
        if (existing >= 0) {
            root.move(existing, index);
            return;
        }
        let dest = index;
        if (dest < 0 || dest > list.length)
            dest = list.length;
        list.splice(dest, 0, key);
        root._save(list);
    }

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

    readonly property bool _shown: DockLayout.enabled
    on_ShownChanged: {
        if (!root._shown && root.dragActive)
            root.cancel();
    }

    function beginDrag(id: string, fromDock: bool, index: int, x: real, y: real, screenName: string) {
        if (!DockLayout.enabled)
            return;
        root.dragId = String(id || "");
        root.dragFromDock = fromDock;
        root.dragIndex = index;
        root.dragX = x;
        root.dragY = y;
        root.hoverKind = "";
        root.hoverIndex = -1;
        root.hoverScreen = "";
        const named = String(screenName || "");
        if (named.length)
            root.dragScreen = named;
        else {
            const hit = root.screenAt(x, y);
            root.dragScreen = hit ? String(hit.name || "") : "";
        }
        root.dragActive = root.dragId.length > 0;
    }

    function moveDrag(x: real, y: real) {
        root.dragX = x;
        root.dragY = y;
    }

    function claim(screen: string, kind: string, index: int) {
        root.hoverScreen = screen;
        root.hoverKind = kind;
        root.hoverIndex = index;
    }

    function clearRow(screen: string) {
        if (root.hoverScreen === screen && root.hoverKind === "row")
            root._clearHover();
    }

    function clearTrash(screen: string) {
        if (root.hoverScreen === screen && root.hoverKind === "trash")
            root._clearHover();
    }

    function _clearHover() {
        root.hoverKind = "";
        root.hoverIndex = -1;
        root.hoverScreen = "";
    }

    function finish() {
        const id = root.dragId;
        const fromDock = root.dragFromDock;
        const from = root.dragIndex;
        const kind = root.hoverKind;
        const to = root.hoverIndex;
        root.cancel();
        if (!id.length)
            return;
        if (kind === "trash" && fromDock) {
            root.removeAt(from);
            return;
        }
        if (kind === "row") {
            if (fromDock)
                root.move(from, to);
            else
                root.insertAt(id, to);
        }
    }

    function cancel() {
        root.dragActive = false;
        root.dragId = "";
        root.dragFromDock = false;
        root.dragIndex = -1;
        root.dragScreen = "";
        root._clearHover();
    }
}
