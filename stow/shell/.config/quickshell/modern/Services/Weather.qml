// Open-Meteo current temperature. Optional: curl failure is soft —
// display stays empty and the weather widget shows the i18n fallback.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool available: false
    property real tempC: 0
    property string display: ""
    property bool watching: false

    readonly property string _url: {
        const w = Config.widgets?.weather ?? {};
        const manual = w.manualLocation || "";
        const parts = String(manual).split(",");
        if (parts.length >= 2) {
            const lat = Number(parts[0].trim());
            const lon = Number(parts[1].trim());
            if (!isNaN(lat) && !isNaN(lon))
                return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m`;
        }
        return "";
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: 600000
        running: root.watching && root._url.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (root._url.length === 0) {
            root.available = false;
            root.display = "";
            return;
        }
        proc.command = ["curl", "-fsS", "--max-time", "8", root._url];
        proc.running = true;
    }

    function _parse(text: string) {
        try {
            const j = JSON.parse(text);
            const t = j?.current?.temperature_2m;
            if (typeof t !== "number") {
                root.available = false;
                return;
            }
            root.tempC = t;
            root.available = true;
            const units = Config.widgets?.weather?.units ?? "metric";
            if (units === "imperial")
                root.display = `${Math.round(t * 9 / 5 + 32)}°`;
            else
                root.display = `${Math.round(t)}°`;
        } catch (e) {
            root.available = false;
            root.display = "";
        }
    }
}
