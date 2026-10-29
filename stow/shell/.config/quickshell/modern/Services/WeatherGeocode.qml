// Open-Meteo city search for Settings weather. Debounced; values are
// "lat,lon" so weather-fetch.sh can pass them straight to the forecast.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var results: []
    property bool searching: false
    property string _needle: ""
    property string _sent: ""

    function search(text: string) {
        root._needle = String(text || "").trim();
        wait.restart();
    }

    function labelFor(value: string): string {
        const rows = root.results || [];
        const want = String(value || "");
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === want)
                return String(rows[i].titleValue || "");
        }
        return "";
    }

    Timer {
        id: wait
        interval: Motion.mediumMs
        onTriggered: root._go()
    }

    function _go() {
        const q = root._needle;
        if (q.length < 2) {
            root.results = [];
            root.searching = false;
            return;
        }
        if (proc.running && root._sent === q)
            return;
        root._sent = q;
        root.searching = true;
        proc.running = false;
        proc.command = [Paths.script("weather-geocode.sh"), q];
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._sent !== root._needle)
                    return;
                try {
                    const rows = JSON.parse((this.text || "").trim() || "[]");
                    root.results = Array.isArray(rows) ? rows : [];
                } catch (e) {
                    root.results = [];
                    Logger.error("Weather", String(e));
                }
                root.searching = false;
            }
        }
        onExited: (code) => {
            if (code !== 0)
                root.searching = false;
        }
    }
}
