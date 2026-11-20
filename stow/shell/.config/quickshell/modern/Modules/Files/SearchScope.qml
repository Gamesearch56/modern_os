import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MIconButton {
    id: root

    iconName: root._icon
    key: "files.search.where"
    tip: true
    onClicked: menu.open = !menu.open

    readonly property string _icon: {
        const rows = root._rows;
        for (let i = 0; i < rows.length; i++) {
            if (root._on(rows[i]))
                return rows[i].icon;
        }
        return "folder";
    }

    readonly property var _rows: {
        void [Storage.otherInternal, Storage.external, Paths.home];
        const rows = [
            { scope: "folder", path: "", key: "files.search.folder", label: "", icon: "folder" },
            { scope: "home", path: "", key: "files.search.home", label: "", icon: "user-home" }
        ];
        const seen = {};
        const home = String(Paths.home || "");
        const lists = [Storage.otherInternal, Storage.external];
        for (let n = 0; n < lists.length; n++) {
            const list = lists[n] || [];
            for (let i = 0; i < list.length; i++) {
                const mount = String(list[i].mount || "");
                if (mount.charAt(0) !== "/" || mount === "/" || mount === home || seen[mount])
                    continue;
                seen[mount] = true;
                rows.push({
                    scope: "folder",
                    path: mount,
                    key: "",
                    label: String(list[i].title || list[i].name || mount),
                    icon: list[i].external ? "drive-removable-media" : "drive-harddisk"
                });
            }
        }
        rows.push({ scope: "computer", path: "", key: "files.search.computer", label: "", icon: "computer" });
        return rows;
    }

    function _on(row): bool {
        if (!row || FilesSearch.scope !== row.scope)
            return false;
        if (row.scope !== "folder")
            return true;
        return String(FilesSearch.rootPath || "") === String(row.path || "");
    }

    MPopup {
        id: menu
        width: Tokens.spacing.xxl * 8
        height: column.implicitHeight + Tokens.spacing.md * 2

        Column {
            id: column
            width: parent.width
            spacing: Tokens.spacing.xxs

            Repeater {
                model: root._rows
                delegate: MListItem {
                    required property var modelData
                    width: column.width
                    height: implicitHeight
                    compact: true
                    iconName: modelData.icon
                    titleKey: modelData.key || ""
                    titleValue: modelData.label || ""
                    selected: root._on(modelData)
                    onClicked: {
                        FilesSearch.choose(modelData.scope, modelData.path, Files.path, Files.showHidden);
                        menu.open = false;
                    }
                }
            }
        }
    }
}
