pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// gio mounts the address. Stdin is closed so a password prompt cannot hang.

Singleton {
    id: root

    property string _out: ""
    property string _then: "go"

    function connect(uri: string, then: string) {
        const text = String(uri || "").trim();
        if (!text.length || proc.running)
            return;
        root._out = "";
        root._then = String(then || "go");
        proc.command = [Paths.script("files-places.sh"), "connect", text];
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._out = String(this.text || "")
        }
        onExited: (code) => {
            if (code !== 0) {
                Files.failed("connect");
                return;
            }
            let info = ({});
            try { info = JSON.parse(root._out || "{}"); } catch (e) { info = ({}); }
            const path = String(info.path || "");
            FilesPlaces.reload();
            if (path.charAt(0) !== "/")
                return;
            if (root._then === "window")
                FilesExtra.open(path);
            else if (root._then === "tab") {
                if (!FilesTabs.paths.length && Files.path.charAt(0) === "/")
                    FilesTabs.add(Files.path);
                FilesTabs.add(path);
                Files.go(path, true);
            } else
                FilesPlaces.mounted(path);
        }
    }
}
