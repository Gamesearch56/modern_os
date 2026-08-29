// Local assistant via `ollama run` when that binary exists. chat(text)
// appends the user turn, then the model reply, onto history. Missing
// ollama fails soft (history still records the user line).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var history: []
    property bool busy: false
    property bool panelOpen: false
    property string hostScreenName: ""
    property string lastError: ""
    property bool _awaiting: false
    property bool _exited: false
    property bool _outDone: false
    property bool _done: false
    property int _code: 0
    property string _stdout: ""
    property string _stderr: ""

    IpcHandler {
        target: "ai"
        function toggle() { root.toggleFocused(); }
        function show() { root.showFocused(); }
        function hide() { root.hide(); }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._stdout = this.text;
                root._outDone = true;
                root._tryFinish();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._stderr = this.text;
                if (this.text.trim().length > 0)
                    Logger.warn("Ai", this.text.trim());
            }
        }
        onExited: (code) => {
            root._code = code;
            root._exited = true;
            Qt.callLater(root._tryFinish);
        }
    }

    function toggle(screen: var) {
        const name = root._nameOf(screen);
        if (root.panelOpen && root.hostScreenName === name) {
            root.hide();
            return;
        }
        root.hostScreenName = name;
        root.panelOpen = true;
    }

    function toggleFocused() {
        root.toggle({ name: root._focusedScreenName() });
    }

    function showFocused() {
        root.hostScreenName = root._focusedScreenName();
        root.panelOpen = true;
    }

    function hide() {
        root.panelOpen = false;
        root.hostScreenName = "";
    }

    function openOn(screen: var): bool {
        if (!root.panelOpen)
            return false;
        if (!root.hostScreenName)
            return true;
        const name = root._nameOf(screen);
        if (name && name === root.hostScreenName)
            return true;
        const mon = Hypr.monitorForScreen(screen);
        if (mon && String(mon.name) === root.hostScreenName)
            return true;
        return false;
    }

    function _nameOf(screen: var): string {
        if (screen && screen.name)
            return String(screen.name);
        return "";
    }

    function _focusedScreenName(): string {
        const hyprName = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s)
                continue;
            if (hyprName && s.name && String(s.name) === hyprName)
                return String(s.name);
            const mon = Hypr.monitorForScreen(s);
            if (hyprName && mon && String(mon.name) === hyprName)
                return String(s.name || mon.name);
        }
        if (hyprName)
            return hyprName;
        if (screens.length > 0 && screens[0] && screens[0].name)
            return String(screens[0].name);
        return "";
    }

    function chat(text: string) {
        const q = (text || "").trim();
        if (!q || root.busy)
            return;
        if ((Config.accounts?.ai?.provider ?? "ollama") === "none")
            return;
        try {
            root.history = root.history.concat([{ role: "user", text: q }]);
            const model = Config.accounts?.ai?.ollamaModel ?? "llama3";
            root.busy = true;
            root._awaiting = true;
            root.lastError = "";
            root._stdout = "";
            root._stderr = "";
            root._done = false;
            root._exited = false;
            root._outDone = false;
            root._code = 0;
            proc.command = ["ollama", "run", model, q];
            proc.running = true;
        } catch (e) {
            root.busy = false;
            root._awaiting = false;
            Logger.error("Ai", String(e));
        }
    }

    function clear() {
        root.history = [];
        root.lastError = "";
    }

    function _collapse(text: string): string {
        return String(text || "").replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim();
    }

    function _errorText(): string {
        const err = (root._stderr || "").trim();
        const low = err.toLowerCase();
        if (root._code === 127 || low.indexOf("ollama:") !== -1 && low.indexOf("not found") !== -1)
            return I18n.t("ai.errorMissing");
        if (low.indexOf("not found") !== -1)
            return I18n.t("ai.errorModel");
        if (err.length > 0) {
            const line = err.split("\n")[0];
            const snippet = line.length > 160 ? line.substring(0, 160) : line;
            return I18n.t("ai.errorStderr", { detail: snippet });
        }
        return I18n.t("ai.errorEmpty");
    }

    function _tryFinish() {
        if (!root._awaiting || root._done || !root._exited || !root._outDone)
            return;
        root._done = true;
        root._awaiting = false;
        root.busy = false;
        const reply = root._collapse(root._stdout);
        if (reply.length === 0) {
            const msg = root._errorText();
            root.lastError = msg;
            Logger.error("Ai", msg);
            root.history = root.history.concat([{ role: "assistant", text: msg }]);
            return;
        }
        root.lastError = "";
        root.history = root.history.concat([{ role: "assistant", text: reply }]);
    }
}
