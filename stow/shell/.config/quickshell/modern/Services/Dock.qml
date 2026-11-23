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
    // The launcher's all-apps grid: there the trash uninstalls instead.
    property bool dragFromGrid: false
    readonly property bool trashShown: root.dragActive && (root.dragFromDock || root.dragFromGrid)
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
        const own = ModernApps.shortName(id);
        return own.length ? own : Apps.labelForId(id);
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
        if (DesktopShortcuts.spawnId(key)) {
            Launcher.hide();
            return;
        }
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

    readonly property DockPlace _place: DockPlace {}
    function screenOrigin(screen: var): point { return root._place.screenOrigin(screen); }
    function pointerToScreen(item: var, edge: string, gx: real, gy: real): point {
        return root._place.pointerToScreen(item, edge, gx, gy);
    }
    function screenAt(x: real, y: real): var { return root._place.screenAt(x, y); }

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

    function beginGridDrag(id: string, x: real, y: real, screenName: string) {
        root.beginDrag(id, false, -1, x, y, screenName);
        if (!root.dragActive)
            return;
        root.dragFromGrid = true;
        AppUninstall.check(root.dragId);
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
        const fromGrid = root.dragFromGrid;
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
        if (kind === "trash" && fromGrid) {
            AppUninstall.drop(id);
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
        root.dragFromGrid = false;
        root.dragIndex = -1;
        root.dragScreen = "";
        root._clearHover();
    }
}
