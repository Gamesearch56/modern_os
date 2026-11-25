pragma Singleton
// Installed-library totals and the game window open right now.
// The scan reads Steam, Lutris, and Heroic files. It does not phone home.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property real hours: 0
    property int installed: 0
    property real bytes: 0
    property real last: 0
    property string lastName: ""
    property bool ready: false

    readonly property string playing: {
        void Hypr.toplevelList;
        const list = Hypr.toplevelList || [];
        for (let i = 0; i < list.length; i++) {
            const name = root._title(list[i]);
            if (name.length)
                return name;
        }
        return "";
    }

    function refresh() {
        proc.running = false;
        Qt.callLater(() => { proc.running = true; });
    }

    function _title(win: var): string {
        if (!win)
            return "";
        const ipc = win.lastIpcObject || ({});
        const cls = String(ipc.class || win.class || ipc.initialClass || "");
        const title = String(win.title || ipc.title || ipc.initialTitle || "");
        if (/^steam$|steamwebhelper|battlenet/i.test(cls))
            return "";
        if (/steam_app_|gamescope|\.exe$|ProjectZomboid|projectzomboid|^wow$|Warcraft/i.test(cls))
            return title.length ? title : cls;
        if (/\.exe|Project Zomboid|World of Warcraft|Warcraft|Diablo|Overwatch|Hearthstone|StarCraft|Call of Duty/i.test(title))
            return title;
        return "";
    }

    function _take(text: string) {
        let row = null;
        try { row = JSON.parse(String(text || "")); } catch (e) { return; }
        if (!row)
            return;
        root.hours = Number(row.hours) || 0;
        root.installed = Number(row.installed) || 0;
        root.bytes = Number(row.bytes) || 0;
        root.last = Number(row.last) || 0;
        root.lastName = String(row.lastName || "");
        root.ready = true;
    }

    Process {
        id: proc
        running: false
        command: [Paths.script("games-library.py")]
        stdout: StdioCollector {
            onStreamFinished: root._take(this.text)
        }
    }
}
