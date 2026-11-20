import QtQuick
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    autoPlace: false
    dismissAnywhere: true
    width: Tokens.spacing.xxl * 8
    height: Math.max(column.implicitHeight, Tokens.spacing.xxl) + Tokens.spacing.md * 2
    x: root._fit(Files.menuX, width, root._host ? root._host.width : 0)
    y: root._fit(Files.menuY, height, root._host ? root._host.height : 0)

    Column {
        id: column
        spacing: Tokens.spacing.xs
        width: parent ? parent.width : 0

        Repeater {
            model: root.rows
            delegate: Item {
                required property var modelData
                width: column.width
                height: modelData.sep ? Tokens.spacing.sm : row.implicitHeight

                MDivider {
                    visible: modelData.sep
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Tokens.stroke.hairline
                }
                MListItem {
                    id: row
                    visible: !modelData.sep
                    width: parent.width
                    height: implicitHeight
                    compact: true
                    titleKey: modelData.key || ""
                    enabled: modelData.on === true
                    destructive: modelData.destructive === true
                    onClicked: root._act(modelData.id)
                }
            }
        }
    }

    readonly property Item _host: Window.window ? Window.window.contentItem : null
    readonly property bool _dir: Files.menuKind === "folder" || Files.menuKind === "favorite"
    readonly property bool _edit: {
        const row = root._entry();
        return !row || row.editable !== false;
    }
    readonly property var rows: root._build()

    function _fit(raw: real, size: real, hostSize: real): real {
        const pad = Tokens.spacing.md;
        if (hostSize <= size + pad * 2)
            return pad;
        return Math.min(Math.max(pad, raw), hostSize - size - pad);
    }

    function _removable(): bool {
        const rows = Storage.external || [];
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].name || "") === Files.menuName)
                return true;
        }
        return false;
    }

    function _entry() {
        const lists = [Files.entries || [], FilesSearch.results || [], FilesPlaces.recent || [], FilesPlaces.favoriteRows(Config.files.favorites)];
        for (let n = 0; n < lists.length; n++) {
            const rows = lists[n];
            for (let i = 0; i < rows.length; i++) {
                if (rows[i].path === Files.menuPath)
                    return rows[i];
            }
        }
        return null;
    }

    function _locked(): bool {
        const row = root._entry();
        return !!(row && (row.readable === false || row.canRead === false));
    }

    function _build() {
        const kind = Files.menuKind;
        const path = Files.menuPath;
        const rows = [];
        function add(id, key, on, destructive) {
            rows.push({ sep: false, id: id, key: key, on: on, destructive: !!destructive });
        }
        function sep() {
            if (rows.length && !rows[rows.length - 1].sep)
                rows.push({ sep: true, id: "", key: "", on: false, destructive: false });
        }
        if (kind === "selection") {
            add("zip", "files.menu.zip", Files.place === "folder" && Files.path.charAt(0) === "/", false);
            sep();
            add("copy", "files.menu.copy", true, false);
            add("cut", "files.menu.cut", true, false);
            sep();
            add("trash", "files.menu.trash", true, true);
            return rows;
        }
        if (kind === "blank") {
            add("newFolder", "files.menu.newFolder", true, false);
            add("newFile", "files.menu.newFile", true, false);
            if (Files.clipboard.length > 0) {
                sep();
                add("paste", "files.menu.paste", true, false);
            }
            return rows;
        }
        if (kind === "recent") {
            add("clearRecent", "files.places.clearRecent", true, false);
            return rows;
        }
        if (kind === "trashPlace") {
            add("empty", "files.menu.empty", true, true);
            return rows;
        }
        if (kind === "network") {
            add("connect", "files.network.connect", true, false);
            return rows;
        }
        if (kind === "net") {
            add("open", "files.menu.open", path.length > 0 || Files.menuName.length > 0, false);
            return rows;
        }
        if (kind === "trash") {
            add("restore", "files.menu.restore", true, false);
            add("delete", "files.menu.delete", true, true);
            return rows;
        }
        if (kind === "disk") {
            add("openDisk", "files.menu.open", path.length > 0, false);
            if (root._removable()) {
                sep();
                add("eject", "files.menu.eject", true, false);
            }
            return rows;
        }
        const dir = root._dir || (root._entry() && root._entry().dir);
        const locked = root._locked();
        const zip = !dir && path.toLowerCase().endsWith(".zip");
        add("open", "files.menu.open", !locked, false);
        if (zip)
            add("extract", "files.menu.extract", !locked, false);
        if (Files.place === "folder" && path.charAt(0) === "/")
            add("zip", "files.menu.zip", !locked, false);
        if (Files.place === "favorites" || Files.place === "recent")
            add("location", "files.menu.openLocation", path.charAt(0) === "/", false);
        if (dir) {
            add("tab", "files.menu.openTab", !locked, false);
            add("window", "files.menu.openWindow", !locked, false);
        }
        sep();
        add("rename", "files.menu.rename", root._edit && !locked, false);
        add("copy", "files.menu.copy", !locked, false);
        add("cut", "files.menu.cut", root._edit && !locked, false);
        if (Files.clipboard.length > 0)
            add("paste", "files.menu.paste", !(locked && dir), false);
        sep();
        add("favorite", FilesPlaces.favorite(path) ? "files.menu.unfavorite" : "files.menu.favorite", true, false);
        add("props", "files.menu.properties", true, false);
        sep();
        add("trash", "files.menu.trash", root._edit && !locked, true);
        return rows;
    }

    function _act(id: string) {
        const items = root.rows || [];
        for (let i = 0; i < items.length; i++) {
            if (items[i].id === id && items[i].on !== true)
                return;
        }
        const path = Files.menuPath;
        const dir = root._dir || !!(root._entry() && root._entry().dir);
        Files.menuOpen = false;
        root.open = false;
        if (id === "newFolder")
            Files.askName("dir");
        else if (id === "newFile")
            Files.askName("file");
        else if (id === "open") {
            if (Files.menuKind === "net" && path.charAt(0) !== "/")
                FilesNet.connect(Files.menuName);
            else
                Files.show(path);
        } else if (id === "connect") {
            Files.namingKind = "server";
            Files.naming = true;
        }
        else if (id === "location") {
            const slash = path.lastIndexOf("/");
            const parent = slash > 0 ? path.slice(0, slash) : "/";
            Files.go(parent, true, [path]);
        }
        else if (id === "tab") {
            if (path.charAt(0) !== "/")
                return;
            if (!FilesTabs.paths.length && Files.path.charAt(0) === "/")
                FilesTabs.add(Files.path);
            FilesTabs.add(path);
        } else if (id === "window")
            FilesExtra.open(path);
        else if (id === "rename")
            Files.renaming = path;
        else if (id === "zip")
            FilesZip.ask();
        else if (id === "extract")
            FilesZip.unpack(path);
        else if (id === "copy") {
            if (Files.menuKind !== "selection")
                Files.selected = [path];
            Files.copy();
        } else if (id === "cut") {
            if (Files.menuKind !== "selection")
                Files.selected = [path];
            Files.cut();
        } else if (id === "paste")
            Files.paste(dir && path.length ? path : "");
        else if (id === "favorite")
            FilesPlaces.toggleFavorite(path);
        else if (id === "props") {
            Files.propertiesOpen = true;
            FilesAccess.load(path);
        } else if (id === "trash")
            FilesTrash.move(Files.menuKind === "selection" ? Files.selected : [path]);
        else if (id === "delete") {
            Files.selected = [path];
            Files.ask("delete");
        } else if (id === "clearRecent")
            FilesPlaces.clearRecent();
        else if (id === "empty")
            Files.ask("empty");
        else if (id === "eject") {
            Files.menuOpen = false;
            Storage.askEject(Files.menuName, "", "files");
        }
        else if (id === "restore")
            FilesTrash.restore(Files.menuName);
        else if (id === "openDisk")
            Files.go(path, true);
    }

    Connections {
        target: Files
        function onMenuOpenChanged() { root.open = Files.menuOpen; }
        function onMenuXChanged() { if (Files.menuOpen) root.open = true; }
        function onMenuYChanged() { if (Files.menuOpen) root.open = true; }
    }

    onOpenChanged: {
        if (!root.open && Files.menuOpen)
            Files.menuOpen = false;
    }
}
