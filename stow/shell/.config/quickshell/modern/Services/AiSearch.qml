// Brave Search key in gitignored secrets.json. The chat script reads
// the file itself, so this only stores the key and whether one is set.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property bool hasKey: Secrets.value("brave", "apiKey").length > 0

    function setKey(raw: string) {
        Secrets.put("brave", { apiKey: raw });
    }

    function openKeys() {
        Quickshell.execDetached(["xdg-open", "https://api-dashboard.search.brave.com/app/keys"]);
    }
}
