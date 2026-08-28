// KDE Connect device list. D-Bus bindings are not assumed here —
// kdeconnect-cli is the stable CLI and is owned by this Service so
// Modules never spawn a process.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var devices: []
    property bool watching: false
    readonly property int connectedCount: root.devices.length

    Process {
        id: proc
        command: ["kdeconnect-cli", "--list-devices", "--id-only"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: Config.kdeconnect.enabled ? 15000 : 60000
        running: root.watching && Config.kdeconnect.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (Config.kdeconnect.enabled)
            root.refresh();
    }

    function refresh() {
        if (!Config.kdeconnect.enabled)
            return;
        proc.running = true;
    }

    function _parse(text: string) {
        try {
            const lines = text.trim().split("\n").filter(s => s.length > 0 && s.indexOf("error") === -1);
            const next = [];
            for (let i = 0; i < lines.length; i++)
                next.push({ id: lines[i].trim() });
            root.devices = next;
        } catch (e) {
            Logger.warn("KdeConnect", String(e));
            root.devices = [];
        }
    }
}
