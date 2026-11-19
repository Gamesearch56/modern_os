// Brave Search key in gitignored secrets.json. The chat script reads
// the file itself, so this only stores the key and whether one is set.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool hasKey: false

    FileView {
        id: secretsFile
        path: Paths.configHome + "/modern/secrets.json"
        watchChanges: true
        printErrors: false
        onLoaded: root._ingest(text())
        onLoadFailed: root.hasKey = false
    }

    function setKey(raw: string) {
        const k = String(raw || "").trim();
        let obj = ({});
        try {
            obj = JSON.parse(secretsFile.text() || "{}") || ({});
        } catch (e) {
            obj = ({});
        }
        if (!obj.brave || typeof obj.brave !== "object")
            obj.brave = ({});
        if (k.length)
            obj.brave.apiKey = k;
        else
            delete obj.brave.apiKey;
        try {
            secretsFile.setText(JSON.stringify(obj, null, 2) + "\n");
        } catch (err) {
            Logger.error("Ai", "secrets write failed");
            return;
        }
        root.hasKey = k.length > 0;
    }

    function openKeys() {
        Quickshell.execDetached(["xdg-open", "https://api-dashboard.search.brave.com/app/keys"]);
    }

    function _ingest(raw: string) {
        let on = false;
        try {
            const data = JSON.parse(String(raw || "{}")) || ({});
            on = String((data.brave && data.brave.apiKey) || "").trim().length > 0;
        } catch (e) {
            on = false;
        }
        root.hasKey = on;
    }
}
