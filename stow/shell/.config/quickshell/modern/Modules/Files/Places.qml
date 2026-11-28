// Sidebar groups. A new place is another row here, not a change to the window.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

Flickable {
    id: root

    property int _over: 0
    property string _armed: ""

    contentHeight: col.implicitHeight
    focus: true
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: (drag) => { FilesDrag.offer(drag); FilesDrag.cover(); root._over += 1; }
        onExited: { root._over = Math.max(0, root._over - 1); FilesDrag.uncover(); }
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: Tokens.spacing.xxs

        Repeater {
            model: root._rows
            delegate: Item {
                id: placeWrap
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: placeRow.implicitHeight
                readonly property string _drop: {
                    if (modelData.kind === "trash")
                        return "trash";
                    const path = String(modelData.path || "");
                    return path.charAt(0) === "/" ? path : "";
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: Colors.color.primaryContainer
                    visible: FilesDrag.active && placeWrap._drop.length > 0 && FilesDrag.drop === placeWrap._drop
                }
                MListItem {
                    id: placeRow
                    anchors.fill: parent
                    variant: "nav"
                    iconName: modelData.icon
                    titleKey: modelData.key || ""
                    titleValue: modelData.value || ""
                    selected: root._current(modelData)
                    onClicked: root._open(modelData)
                    onRightClicked: (x, y) => {
                        const p = root._at(placeRow, x, y);
                        root._menu(modelData, p.x, p.y);
                    }
                }
                PlaceTarget { target: placeWrap._drop }
            }
        }

        MDivider {
            visible: root._disks.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.sm
            Layout.bottomMargin: Tokens.spacing.sm
            Layout.preferredHeight: Tokens.stroke.hairline
        }

        Repeater {
            model: root._disks
            delegate: Item {
                id: diskWrap
                required property var modelData
                readonly property string mount: String(modelData.mount || "")
                readonly property bool removable: !!modelData.external
                readonly property string _drop: mount.charAt(0) === "/" ? mount : ""
                Layout.fillWidth: true
                implicitHeight: diskRow.implicitHeight
                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: Colors.color.primaryContainer
                    visible: FilesDrag.active && diskWrap._drop.length > 0 && FilesDrag.drop === diskWrap._drop
                }
                MListItem {
                    id: diskRow
                    anchors.fill: parent
                    variant: "nav"
                    iconName: removable ? "drive-removable-media" : "drive-harddisk"
                    titleValue: String(modelData.title || modelData.name || "")
                    selected: Files.place === "folder" && mount.length > 0 && mount === Files.path
                    onClicked: { root.forceActiveFocus(); Files.go(mount, true); }
                    onRightClicked: (x, y) => {
                        const p = root._at(diskRow, x, y);
                        Files.openMenu("disk", mount, String(modelData.name || ""), p.x, p.y);
                    }
                    MIconButton {
                        visible: diskWrap.removable
                        iconName: "media-eject"
                        key: "files.places.eject"; tip: true; tipEdge: "right"
                        size: Tokens.spacing.xl
                        iconSize: Tokens.icon.sm
                        glyphColor: diskRow.selected ? Chrome.navSelected.fg : Colors.color.onSurface
                        layerColor: diskRow.selected ? Chrome.navSelected.fg : Colors.color.primary
                        enabled: Storage.ejecting !== String(modelData.name || "")
                        onClicked: Storage.askEject(String(modelData.name || ""), String(modelData.title || ""), "files")
                    }
                }
                PlaceTarget { target: diskWrap._drop }
            }
        }
    }

    Rectangle {
        enabled: false
        anchors.fill: parent
        z: 5
        color: "transparent"
        radius: Tokens.radius.medium
        border.width: FilesDrag.active && root._over > 0 ? Tokens.stroke.focus : 0
        border.color: Colors.color.primary
    }

    component PlaceTarget: Item {
        id: hint
        property string target: ""
        anchors.fill: parent
        z: 4
        readonly property bool _on: FilesDrag.active && hint.target.length > 0 && FilesDrag.drop === hint.target

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.full
            color: "transparent"
            border.width: hint._on ? Tokens.stroke.focus : 0
            border.color: Colors.color.primary
        }
        DropArea {
            anchors.fill: parent
            enabled: hint.target.length > 0
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                FilesDrag.offer(drag);
                FilesDrag.cover();
                root._over += 1;
                root._armed = hint.target;
                FilesDrag.drop = hint.target;
            }
            onExited: {
                root._over = Math.max(0, root._over - 1);
                if (FilesDrag.drop === hint.target) {
                    FilesDrag.drop = "";
                    root._armed = "";
                }
                FilesDrag.uncover();
            }
            onDropped: (drag) => {
                FilesDrag.offer(drag);
                if (!FilesDrag.active || !hint.target.length)
                    return;
                FilesDrag.drop = hint.target;
                drag.accept(Qt.MoveAction);
                FilesDrag.land();
            }
        }
    }

    function _dir(id: string): string {
        const dirs = FilesPlaces.dirs || [];
        for (let i = 0; i < dirs.length; i++)
            if (dirs[i].id === id) return String(dirs[i].path || "");
        if (id === "home") return String(Paths.home || "");
        if (dirs.length) return "";
        const key = id === "downloads" ? "DOWNLOAD" : id === "pictures" ? "PICTURES" : id === "videos" ? "VIDEOS" : "";
        const mapped = String((XdgDirs._map || {})[key] || "");
        return mapped.charAt(0) === "/" ? mapped : "";
    }

    readonly property var _rows: {
        const rows = [];
        if (Files.showRecent) rows.push({ id: "recent", key: "files.places.recent", icon: "document-open-recent", path: "", kind: "recent" });
        rows.push({ id: "home", key: "files.places.home", icon: "user-home", path: root._dir("home"), kind: "place" });
        rows.push({ id: "favorites", key: "files.places.favorites", icon: "folder-favorites", path: "", kind: "favorites" });
        const folders = [
            { id: "downloads", icon: "folder-download" },
            { id: "pictures", icon: "folder-pictures" },
            { id: "videos", icon: "folder-videos" }
        ];
        for (let i = 0; i < folders.length; i++) {
            const path = root._dir(folders[i].id);
            if (!path.length)
                continue;
            rows.push({
                id: folders[i].id,
                key: "files.places." + folders[i].id,
                icon: folders[i].icon,
                path: path,
                kind: "place"
            });
        }
        rows.push({ id: "computer", key: "files.places.computer", icon: "computer", path: "/", kind: "place" });
        if (Files.showNetwork) rows.push({ id: "network", key: "files.places.network", icon: "network-workgroup", path: "", kind: "network" });
        rows.push({ id: "trash", key: "files.places.trash", icon: "user-trash", path: "", kind: "trash" });
        return rows;
    }

    readonly property var _disks: {
        const rows = [];
        const other = Storage.otherInternal || [];
        for (let i = 0; i < other.length; i++) {
            if (String(other[i].mount || "").charAt(0) === "/")
                rows.push(other[i]);
        }
        const removable = Storage.external || [];
        for (let k = 0; k < removable.length; k++) {
            if (String(removable[k].mount || "").charAt(0) === "/")
                rows.push(removable[k]);
        }
        return rows;
    }

    function _current(row: var): bool {
        if (row.kind === "favorites")
            return Files.place === "favorites";
        if (row.kind === "recent")
            return Files.place === "recent";
        if (row.kind === "trash")
            return Files.place === "trash";
        if (row.kind === "network")
            return Files.place === "network";
        return Files.place === "folder" && row.path === Files.path;
    }

    function _open(row) {
        root.forceActiveFocus();
        const kind = String(row.kind || "");
        if (kind === "recent" || kind === "trash" || kind === "network" || kind === "favorites") {
            Files.showPlace(kind);
            if (kind === "recent") FilesPlaces.reloadRecent();
            else if (kind === "trash") FilesTrash.refresh();
            else if (kind === "network") FilesPlaces.reload();
            return;
        }
        if (row.path)
            Files.go(String(row.path), true);
    }

    function cycle(step: int) {
        const rows = (root._rows || []).slice();
        const disks = root._disks || [];
        for (let i = 0; i < disks.length; i++) rows.push({ kind: "disk", path: String(disks[i].mount || "") });
        const n = rows.length;
        if (!n) return;
        let at = -1;
        for (let i = 0; i < n; i++) {
            const row = rows[i];
            const on = row.kind === "disk" ? Files.place === "folder" && row.path === Files.path : root._current(row);
            if (on) at = i;
        }
        const dir = step < 0 ? -1 : 1;
        const next = at < 0 ? (dir < 0 ? n - 1 : 0) : (at + dir + n) % n;
        root._open(rows[next]);
        root.contentY = Math.max(0, Math.min(next * Tokens.spacing.xxl, Math.max(0, root.contentHeight - root.height)));
    }

    function _at(item, x, y) {
        const host = Window.window ? Window.window.contentItem : item;
        return item.mapToItem(host, x, y);
    }

    function _menu(row, x, y) {
        const place = row.kind === "trash" ? "trashPlace" : row.kind;
        const named = place === "recent" || place === "trashPlace" || place === "network";
        if (named || row.path)
            Files.openMenu(named ? place : "place", named ? "" : row.path, "", x, y);
    }

    Component.onCompleted: {
        Storage.watching = true;
        FilesPlaces.reload();
    }
}
