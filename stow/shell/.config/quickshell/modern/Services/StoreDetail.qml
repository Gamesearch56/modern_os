// One-package info plus allowlisted screenshot URLs.
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var info: ({})
    property var shots: []
    property var comments: []
    property int votes: 0
    property bool loading: false
    property string _name: ""

    Process {
        id: infoProc
        running: false
        stdout: StdioCollector { id: infoOut }
        onExited: () => root._applyInfo(infoOut.text)
    }

    Process {
        id: extraProc
        running: false
        stdout: StdioCollector { id: extraOut }
        onExited: () => root._applyExtras(extraOut.text)
    }

    function load(name: string) {
        const n = String(name || "").trim();
        root._name = n;
        root.info = ({ name: n });
        root.shots = [];
        root.comments = [];
        root.votes = 0;
        if (!n.length)
            return;
        root.loading = true;
        infoProc.command = [Paths.script("pkg-detail.sh"), n];
        extraProc.command = [Paths.script("pkg-extras.sh"), n];
        infoProc.running = true;
        extraProc.running = true;
    }

    function clear() {
        infoProc.running = false;
        extraProc.running = false;
        root._name = "";
        root.info = ({});
        root.shots = [];
        root.comments = [];
        root.votes = 0;
        root.loading = false;
    }

    function _applyInfo(text: string) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "{}");
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                root.info = parsed;
        } catch (e) {
            Logger.warn("Store", "detail parse failed");
        }
        if (!extraProc.running)
            root.loading = false;
    }

    function _applyExtras(text: string) {
        try {
            const parsed = JSON.parse(String(text || "").trim() || "{}");
            const shots = [];
            const raw = parsed && parsed.shots ? parsed.shots : [];
            for (let i = 0; i < raw.length; i++) {
                const u = root._shotUrl(raw[i]);
                if (u.length)
                    shots.push(u);
            }
            root.shots = shots;
            root.votes = Number(parsed && parsed.votes || 0);
            root.comments = Array.isArray(parsed && parsed.comments) ? parsed.comments : [];
        } catch (e) {
            root.shots = [];
        }
        if (!infoProc.running)
            root.loading = false;
    }

    function _shotUrl(value): string {
        let u = String(value || "");
        if (u.indexOf("https://screenshots.debian.net/") !== 0)
            return "";
        u = u.replace("/thumbnail/", "/screenshot/");
        u = u.replace("/small/", "/screenshot/");
        return u;
    }
}
