// Steam writes a game shortcut onto the desktop, not into applications/,
// and drops steam_icon_<id>.png into the user icon theme afterwards.
// The theme keeps the names it had when the shell started, so that png
// paints blank. The path here is what the icon widget loads directly.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool ready: false
    property int revision: 0
    property var shortcuts: []
    property var iconFiles: ({})
    property bool _scanning: false
    property bool _again: false
    property bool _watch: true

    readonly property string iconRoot: {
        const home = String(Quickshell.env("HOME") || "");
        return home + "/.local/share/icons/hicolor";
    }

    function iconFor(hint: string): string {
        void root.revision;
        const path = String((root.iconFiles || {})[String(hint || "")] || "");
        if (!path.length)
            return "";
        return "file://" + encodeURI(path);
    }

    function nameFor(id: string): string {
        const key = String(id || "").replace(/\.desktop$/i, "");
        const list = root.shortcuts || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id || "") === key)
                return String(list[i].name || "");
        }
        return "";
    }

    function rows(needle: string): var {
        const n = String(needle || "").trim().toLowerCase();
        const list = root.shortcuts || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const s = list[i];
            const name = String(s.name || "");
            if (n.length && name.toLowerCase().indexOf(n) === -1)
                continue;
            const id = String(s.id || name);
            out.push({
                id: id,
                name: name,
                genericName: "",
                icon: root.iconFor(id) || root.iconFor(s.iconName) || "application-x-executable",
                tint: false,
                exec: null,
                argv: s.argv || [],
                score: 0
            });
        }
        return out;
    }

    function spawn(argv: var): bool {
        const args = argv || [];
        if (!args.length)
            return false;
        Quickshell.execDetached([Paths.script("cursor-busy.sh"), "start"]);
        Quickshell.execDetached(args);
        return true;
    }

    function spawnId(id: string): bool {
        const key = String(id || "").replace(/\.desktop$/i, "");
        const list = root.shortcuts || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id || "") !== key)
                continue;
            return root.spawn(list[i].argv);
        }
        return false;
    }

    function requestScan() {
        if (root._scanning) {
            root._again = true;
            return;
        }
        root._scanning = true;
        scan.running = true;
    }

    function _done(code, text) {
        root._scanning = false;
        if (code === 0) {
            try {
                const data = JSON.parse(String(text || ""));
                if (data && data.shortcuts && data.icons) {
                    root.shortcuts = data.shortcuts;
                    root.iconFiles = data.icons;
                }
            } catch (e) {
                Logger.warn("DesktopShortcuts", "scan failed: " + e);
            }
        } else {
            Logger.warn("DesktopShortcuts", "scan exited " + code);
        }
        root.ready = true;
        root.revision += 1;
        if (root._again) {
            root._again = false;
            Qt.callLater(root.requestScan);
        }
    }

    Process {
        id: scan
        running: false
        command: ["python3", Paths.script("desktop-shortcuts.py")]
        stdout: StdioCollector { id: scanOut }
        onExited: (code) => root._done(code, scanOut.text)
    }

    Process {
        id: watch
        running: root._watch && XdgDirs.desktop.length > 0
        command: ["inotifywait", "-m", "-e", "close_write,move,create,delete", "--format", "%e",
            XdgDirs.desktop, root.iconRoot]
        stdout: SplitParser {
            onRead: (line) => root.requestScan()
        }
        onExited: (code) => {
            if (root._watch)
                root._watch = false;
        }
    }

    Component.onCompleted: root.requestScan()
}
