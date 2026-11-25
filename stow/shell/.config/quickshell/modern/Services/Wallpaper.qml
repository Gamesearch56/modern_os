pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string currentPath: ""
    property bool pickerOpen: false
    property bool providerOpen: false
    property bool _reopenPicker: false
    property bool fetching: false
    property var images: []
    property string pendingSelect: ""
    property string _lastIngest: ""
    property double _lastIngestAt: 0
    readonly property int thumbsRev: thumbs.rev

    readonly property string home: Quickshell.env("HOME")
    readonly property string libraryDir: XdgDirs.wallpapers
    readonly property string sessionBlur: "/var/lib/modern/session/wallpaper-blur.jpg"
    readonly property string stateHome: Paths.stateHome

    signal fetched(string path)
    signal fetchFailed()
    signal openedInBrowser()
    signal chooserStarted(string kind)
    signal chooserFinished(bool reopenPicker)

    FileView {
        id: stateFile
        path: root.stateHome + "/modern/current-wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.currentPath = text().trim()
        onLoadFailed: root.currentPath = ""
    }

    Process {
        id: listProc
        command: [Paths.script("wallpaper-list.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = this.text.trim().split("\n").filter(l => l.length > 0);
                thumbs.rebuild(root.images);
            }
        }
    }

    Process {
        id: importProc
        command: [Paths.script("wallpaper-import.sh")]
        stdout: StdioCollector { id: importOut }
        onExited: (code) => {
            if (code === 2)
                Logger.error("Wallpaper", I18n.t("wallpaper.alreadyInLibrary"));
            else if (code !== 0 && code !== 1)
                Logger.error("Wallpaper", I18n.t("wallpaper.importFailed"));
            else if (code === 0) {
                const lines = importOut.text.trim().split("\n").filter(l => l.length > 0);
                root.pendingSelect = lines.length > 0 ? lines[lines.length - 1] : "";
            }
            const reopen = root._reopenPicker;
            root._reopenPicker = false;
            root.chooserFinished(reopen);
        }
    }

    Process {
        id: deleteProc
        command: [Paths.script("wallpaper-delete.sh")]
        onExited: (code) => {
            if (code === 0)
                root._refresh();
            else
                Logger.error("Wallpaper", I18n.t("wallpaper.removeFailed"));
        }
    }

    Process {
        id: fetchProc
        stdout: StdioCollector { id: fetchOut }
        stderr: StdioCollector { id: fetchErr }
        onExited: (code) => {
            root.fetching = false;
            const path = fetchOut.text.trim().split("\n").filter(l => l.length > 0).pop() || "";
            if (code === 0 && path.length > 0) {
                root._refresh();
                root.fetched(path);
            } else {
                const err = fetchErr.text.trim();
                if (err.length)
                    Logger.warn("Wallpaper", err);
                root.fetchFailed();
            }
        }
    }

    Process {
        id: providerProc
        stdout: SplitParser {
            onRead: (line) => {
                const t = String(line || "").trim();
                if (t.indexOf("INGEST ") === 0)
                    root.ingest(t.slice(7).trim());
            }
        }
        onExited: (code) => {
            const reopen = root._reopenPicker && code === 0;
            root._reopenPicker = false;
            root.providerOpen = false;
            if (code !== 0) {
                Logger.warn("Wallpaper", `provider window exited ${code}; opening the browser instead`);
                root.openInBrowser();
            }
            root.chooserFinished(reopen);
        }
    }

    WallpaperThumbs {
        id: thumbs
    }

    Component.onCompleted: root._refresh()

    IpcHandler {
        target: "wallpaper"
        function picker() { root.pick(); }
        function pick() { root.pick(); }
        function toggle() { root.togglePicker(); }
        function provider() { root.openProvider(); }
        function ingest(path: string): void { root.ingest(path); }
    }

    function pick() { root.setPickerOpen(true); }

    function togglePicker() { root.setPickerOpen(!root.pickerOpen); }

    function setPickerOpen(open: bool) {
        if (open)
            root.closeProvider();
        root.pickerOpen = open;
        if (open)
            root._refresh();
    }

    function hide() {
        root.pickerOpen = false;
        root.closeProvider();
    }

    function providerUrl(): string {
        let u = String(Config.design.wallpaperProvider || "").trim();
        if (u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0 && u.length > 0)
            u = "https://" + u;
        return u;
    }

    function openProvider() {
        root.pickerOpen = false;
        if (providerProc.running) {
            Quickshell.execDetached([
                "hyprctl", "dispatch",
                "hl.dsp.focus({ window = \"title:modern.wallpaper-provider\" })"
            ]);
            return;
        }
        root._reopenPicker = true;
        root.providerOpen = true;
        root.chooserStarted("provider");
    }

    function closeProvider() {
        root._reopenPicker = false;
        providerProc.running = false;
        root.providerOpen = false;
    }

    function ingest(path: string) {
        const p = String(path || "").trim();
        if (!p.length)
            return;
        // WebEngine stages as *.download then renames — ignore partials / rapid duplicates.
        if (/\.(download|crdownload|part|tmp|temp)$/i.test(p))
            return;
        const now = Date.now();
        if (p === root._lastIngest && (now - root._lastIngestAt) < Motion.extraLongMs)
            return;
        root._lastIngest = p;
        root._lastIngestAt = now;
        root.pendingSelect = p;
        root._refresh();
        root.fetched(p);
    }
    function openInBrowser() {
        Quickshell.execDetached(["xdg-open", root.providerUrl()]);
        root.openedInBrowser();
    }

    function fetch(url: string) {
        const u = String(url || "").trim();
        if (!u.length || root.fetching)
            return;
        fetchProc.running = false;
        fetchProc.command = [Paths.script("wallpaper-fetch.sh"), u, root.libraryDir];
        root.fetching = true;
        fetchProc.running = true;
    }

    function clearPendingSelect() { root.pendingSelect = ""; }
    function refresh() { root._refresh(); }

    function tileSource(path: string): string { return thumbs.url(path); }

    function _refresh() { listProc.running = false; Qt.callLater(() => { listProc.running = true; }); }

    function importFile(path: string) {
        importProc.command = [Paths.script("wallpaper-import.sh"), String(path || "")];
        importProc.running = false;
        importProc.running = true;
    }

    function importWallpaper() {
        root.pickerOpen = false;
        root._reopenPicker = true;
        root.chooserStarted("import");
    }

    function beginChooser(kind: string) {
        const k = String(kind || "");
        if (k === "import") { FilesChoose.ask(XdgDirs.pictures, "image", "wallpaper"); return; }
        if (k === "provider") {
            const labels = { back: "wallpaper.providerBack", forward: "wallpaper.providerForward", close: "bar.close" };
            providerProc.command = [Paths.script("wallpaper-provider.sh"), root.providerUrl(), root.libraryDir,
                ExternalTheme.json(), ExternalTheme.strings(labels)];
            providerProc.running = true;
        }
    }

    function canRemove(path: string): bool {
        const p = String(path || "");
        if (!p || p === root.currentPath)
            return false;
        return p.indexOf(root.home + "/.config/modern/wallpapers/") !== 0;
    }

    function remove(path: string) {
        if (!root.canRemove(path))
            return;
        deleteProc.command = [Paths.script("wallpaper-delete.sh"), path];
        deleteProc.running = false;
        Qt.callLater(() => { deleteProc.running = true; });
    }

    function setWallpaper(path: string) {
        if (!path || path.length === 0) {
            Logger.warn("Wallpaper", "setWallpaper called with an empty path");
            return;
        }
        root.currentPath = path;
        root.hide();
        Qt.callLater(() => {
            Colors.armForWallpaper();
            Quickshell.execDetached([Paths.script("wallpaper-show.sh"), path, "", String(Colors.transitionGen)]);
            Theme.applyShown(path);
        });
        Logger.info("Wallpaper", "applied " + path);
    }

    function replay(kind: string) {
        const img = String(root.currentPath || "");
        if (!img.length)
            return;
        const t = String(kind || "");
        if (t.length > 0)
            Quickshell.execDetached([Paths.script("wallpaper-show.sh"), img, t]);
        else
            Quickshell.execDetached([Paths.script("wallpaper-show.sh"), img]);
    }
}
