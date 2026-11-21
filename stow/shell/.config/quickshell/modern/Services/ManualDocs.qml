pragma Singleton

// The documents the ModernOS Manual shows: the user manual and the
// technical reference from the checkout's docs/, read once through
// scripts/manual-index.py so search can look inside every document.
// Also opens web links, which the app cannot do itself.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var docs: []
    property bool loading: false
    property bool failed: false

    signal loaded()

    function reload() {
        if (index.running)
            return;
        root.loading = true;
        root.failed = false;
        index.running = true;
    }

    function byPath(path: string): var {
        for (let i = 0; i < root.docs.length; i++) {
            if (root.docs[i].path === path)
                return root.docs[i];
        }
        return null;
    }

    // Every word has to appear in the title or the text, in any order.
    function search(query: string): var {
        const words = String(query || "").toLowerCase().split(/\s+/).filter(w => w.length > 0);
        if (!words.length)
            return root.docs;
        return root.docs.filter(d => {
            const hay = (d.title + "\n" + d.text).toLowerCase();
            return words.every(w => hay.indexOf(w) !== -1);
        });
    }

    function openExternal(url: string) {
        if (/^(https?|mailto):/i.test(url))
            Quickshell.execDetached(["xdg-open", url]);
    }

    Process {
        id: index
        command: ["python3", Paths.script("manual-index.py"), Paths.repo]
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: (code) => {
            root.loading = false;
            let list = [];
            try {
                list = code === 0 ? JSON.parse(out.text || "[]") : [];
            } catch (e) {
                list = [];
            }
            if (code !== 0)
                Logger.warn("Manual", "manual-index.py exited " + code + ": " + String(err.text || "").trim());
            root.failed = !Array.isArray(list) || list.length === 0;
            root.docs = Array.isArray(list) ? list : [];
            root.loaded();
        }
    }

    Component.onCompleted: root.reload()
}
