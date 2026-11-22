// Owns the gitignored secrets.json: AI keys and calendar credentials.
// Every reader and writer goes through here so the file stays mode 0600
// and an unreadable file is never replaced, losing the other keys in it.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string path: Paths.configHome + "/modern/secrets.json"
    property var store: ({})
    // False while the file exists but is not a JSON object.
    property bool valid: true

    function section(name: string): var {
        const s = root.store[name];
        return s && typeof s === "object" ? s : ({});
    }

    function value(name: string, key: string): string {
        return String(root.section(name)[key] || "").trim();
    }

    // Merges `patch` into one section; an empty value removes the key.
    // Returns false when nothing was written.
    function put(name: string, patch: var): bool {
        if (!root.valid) {
            Logger.error("Secrets", "secrets.json is not valid JSON; leaving it untouched");
            return false;
        }
        const next = JSON.parse(JSON.stringify(root.store));
        const sec = root.section(name);
        const merged = JSON.parse(JSON.stringify(sec));
        for (const key in patch) {
            const v = String(patch[key] === undefined || patch[key] === null ? "" : patch[key]).trim();
            if (v.length)
                merged[key] = v;
            else
                delete merged[key];
        }
        next[name] = merged;
        try {
            file.setText(JSON.stringify(next, null, 2) + "\n");
        } catch (err) {
            Logger.error("Secrets", "write failed: " + err);
            return false;
        }
        root.store = next;
        // QSaveFile keeps an existing file's mode; this covers a file
        // that was created or replaced outside the shell.
        Quickshell.execDetached(["chmod", "600", root.path]);
        return true;
    }

    function _ingest(raw: string) {
        const text = String(raw || "").trim();
        if (!text.length) {
            root.valid = true;
            root.store = ({});
            return;
        }
        try {
            const parsed = JSON.parse(text);
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                throw new Error("not an object");
            root.valid = true;
            root.store = parsed;
        } catch (e) {
            Logger.warn("Secrets", "secrets.json unreadable: " + e);
            root.valid = false;
            root.store = ({});
        }
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root._ingest(text())
        onFileChanged: reload()
        onLoadFailed: {
            root.valid = true;
            root.store = ({});
        }
    }

    // A first write would otherwise create the file with the umask mode.
    Process {
        running: true
        command: ["sh", "-c", "umask 077; [ -e \"$1\" ] || printf '{}\\n' >\"$1\"; chmod 600 \"$1\"", "sh", root.path]
        onExited: (code) => {
            if (code !== 0)
                Logger.warn("Secrets", "could not secure secrets.json (exit " + code + ")");
        }
    }
}
