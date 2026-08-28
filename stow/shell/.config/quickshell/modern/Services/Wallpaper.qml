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
        command: ["bash", "-lc", "pic=$(xdg-user-dir PICTURES 2>/dev/null || true); pic=${pic:-$HOME/Pictures}; find \"$pic/Wallpapers\" \"$pic\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text().trim().split("\n").filter(l => l.length > 0);
                root.images = lines;
            }
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

    function _refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function setWallpaper(path: string) {
        try {
            if (!path || path.length === 0) {
                Logger.warn("Wallpaper", "setWallpaper called with an empty path");
                return;
            }
            root.currentPath = path;
            Quickshell.execDetached(["theme-apply.sh", "--wallpaper", path]);
            Quickshell.execDetached(["wallpaper-sync.sh", path]);
            root.pickerOpen = false;
            Logger.info("Wallpaper", "applied " + path);
        } catch (e) {
            Logger.error("Wallpaper", String(e));
        }
    }
}
