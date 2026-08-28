// Owns the current wallpaper path, the picker open-state, and the
// directory listing. Modules/Wallpaper never touches disk or spawns
// theme-apply — derived copies for the greeter/Plymouth live in
// sharedDir so those processes never read $HOME (docs/DECISIONS.md #14).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string currentPath: ""
    property bool pickerOpen: false
    property var images: []
    property string sharedDir: "/var/lib/modern/session"

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: {
        const env = Quickshell.env("XDG_STATE_HOME");
        return (env && env.length > 0) ? env : (root.home + "/.local/state");
    }

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
        running: false
        command: [root.home + "/modern_dotfile/scripts/wallpaper-list.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0);
                root.images = lines;
            }
        }
    }

    Process {
        id: importProc
        running: false
        command: [root.home + "/modern_dotfile/scripts/wallpaper-import.sh"]
        onExited: (code) => {
            if (code === 2)
                Logger.error("Wallpaper", I18n.t("wallpaper.alreadyInLibrary"));
            else if (code !== 0 && code !== 1)
                Logger.error("Wallpaper", I18n.t("wallpaper.importFailed"));
            else if (code === 0)
                root._refresh();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function picker() { root.pick(); }
        function pick() { root.pick(); }
        function toggle() { root.togglePicker(); }
    }

    function pick() {
        root.pickerOpen = true;
        root._refresh();
    }

    function togglePicker() {
        root.setPickerOpen(!root.pickerOpen);
    }

    function setPickerOpen(open: bool) {
        root.pickerOpen = open;
        if (open)
            root._refresh();
    }

    function hide() { root.setPickerOpen(false); }

    function _refresh() {
        listProc.running = false;
        Qt.callLater(() => {
            listProc.running = true;
        });
    }

    function importWallpaper() {
        try {
            importProc.running = false;
            importProc.running = true;
        } catch (e) {
            Logger.error("Wallpaper", String(e));
        }
    }

    function setWallpaper(path: string) {
        try {
            if (!path || path.length === 0) {
                Logger.warn("Wallpaper", "setWallpaper called with an empty path");
                return;
            }
            root.currentPath = path;
            Quickshell.execDetached([root.home + "/modern_dotfile/scripts/theme-apply.sh", "--wallpaper", path]);
            Quickshell.execDetached([root.home + "/modern_dotfile/scripts/wallpaper-sync.sh", path]);
            root.pickerOpen = false;
            Logger.info("Wallpaper", "applied " + path);
        } catch (e) {
            Logger.error("Wallpaper", String(e));
        }
    }
}
