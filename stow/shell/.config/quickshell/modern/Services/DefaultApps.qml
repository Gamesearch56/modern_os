pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// Shipped text editor, image viewer, and video player.
// install/manifests/default-apps.json is the list. A non-empty
// apps.defaults value in config.json wins; Settings writes that file only.
Singleton {
    id: root

    property var _roles: ({})

    function _item(role: string): var {
        const roles = root._roles || ({});
        const item = roles[role];
        return item || null;
    }

    function desktop(role: string): string {
        const item = root._item(role);
        return item ? String(item.desktop || "") : "";
    }

    // Picker pins: the desktop id plus its short name, so a NoDisplay
    // handler for the shipped app still appears.
    function ids(role: string): var {
        const id = root.desktop(role);
        if (!id.length)
            return [];
        const tail = id.replace(/\.desktop$/, "").split(".").pop();
        if (tail && tail !== id)
            return [id, tail];
        return [id];
    }

    // Last-resort argv when no desktop entry is installed. An exec
    // override wins over the package name.
    function launchArgv(role: string): var {
        const item = root._item(role);
        if (!item)
            return [];
        const exec = item.exec;
        if (exec && exec.length)
            return exec;
        const pkgs = item.packages;
        if (pkgs && pkgs.length)
            return [String(pkgs[0])];
        return [];
    }

    FileView {
        id: file
        path: Paths.repo + "/install/manifests/default-apps.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onPathChanged: reload()
        onLoaded: {
            try {
                root._roles = JSON.parse(String(text() || "").trim() || "{}") || ({});
            } catch (e) {
                root._roles = ({});
                Logger.warn("DefaultApps", "manifest is not valid JSON");
            }
        }
        onLoadFailed: root._roles = ({})
    }
}
