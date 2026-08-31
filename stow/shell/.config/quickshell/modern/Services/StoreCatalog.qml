// Curated popular + category allowlists from store/catalog.json.
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var popular: []
    property var categories: []
    signal loaded()

    FileView {
        path: Paths.configHome + "/modern/store/catalog.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root._parse(text());
            root.loaded();
        }
        onLoadFailed: {
            root._parse("");
            root.loaded();
        }
    }

    function iconFor(id: string): string {
        const cats = root.categories;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === id)
                return cats[i].icon || "package-x-generic-symbolic";
        }
        return "package-x-generic-symbolic";
    }

    function packages(id: string) {
        const cats = root.categories;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === id)
                return cats[i].packages || [];
        }
        return [];
    }

    function _parse(text: string) {
        try {
            const data = JSON.parse(String(text || "").trim() || "{}");
            root.popular = Array.isArray(data.popular) ? data.popular : [];
            root.categories = Array.isArray(data.categories) && data.categories.length
                ? data.categories
                : root._fallback();
        } catch (e) {
            root.popular = [];
            root.categories = root._fallback();
        }
    }

    function _fallback() {
        return [
            { id: "discover", icon: "view-grid-symbolic" },
            { id: "installed", icon: "folder-download-symbolic" }
        ];
    }
}
