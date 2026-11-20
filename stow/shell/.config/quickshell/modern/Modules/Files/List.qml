import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Flickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: Math.max(column.implicitHeight, height)
    boundsBehavior: Flickable.StopAtBounds

    SearchRank { id: rank }

    readonly property var rows: {
        const folders = Files.foldersFirst;
        if (FilesSearch.active)
            return rank.order(FilesSearch.results, folders);
        if (Files.place === "trash")
            return FilesTrash.items || [];
        if (Files.place === "favorites")
            return FilesPlaces.favoriteRows(Config.files.favorites);
        if (Files.place === "recent")
            return FilesPlaces.recent || [];
        if (Files.place === "network") {
            const nets = FilesPlaces.mounts || [];
            const out = [];
            for (let i = 0; i < nets.length; i++)
                out.push({ name: nets[i].name || nets[i].path || nets[i].uri, path: nets[i].path || "", uri: nets[i].uri || "", dir: true, share: true, size: -1 });
            return out;
        }
        return Files.entries || [];
    }

    function reveal(index: int) {
        const item = cells.itemAt(index);
        if (!item)
            return;
        const top = item.y;
        const bottom = top + item.height;
        if (top < root.contentY)
            root.contentY = top;
        else if (bottom > root.contentY + root.height)
            root.contentY = Math.max(0, bottom - root.height);
    }

    onRowsChanged: FilesThumbs.watch(root.rows)
    Component.onCompleted: FilesThumbs.watch(root.rows)

    Connections {
        target: Files
        function onPathChanged() { root.contentY = 0; }
        function onPlaceChanged() { root.contentY = 0; }
    }

    BodyScroll {
        flick: root
        repeater: cells
        page: root
        mode: "list"
    }

    FileFacts { id: facts }

    Column {
        id: column
        width: root.width
        spacing: Tokens.spacing.xxs

        RowLayout {
            width: parent.width
            height: Tokens.spacing.xl
            spacing: Tokens.spacing.sm

            Item { Layout.preferredWidth: Tokens.spacing.sm + Tokens.icon.md + Tokens.spacing.sm }
            MText {
                key: "files.details.name"
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MText {
                visible: Files.showSize && (Files.place !== "network" || FilesSearch.active)
                key: "files.details.size"
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: facts.colSize
            }
            MText {
                visible: Files.showCreated && (Files.place !== "network" || FilesSearch.active)
                key: "files.details.created"
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: facts.colDate
            }
            MText {
                visible: Files.showModified && (Files.place !== "network" || FilesSearch.active)
                key: "files.details.updated"
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: facts.colDate
            }
            MText {
                visible: Files.showType && (Files.place !== "network" || FilesSearch.active)
                key: "files.details.type"
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: facts.colType
            }
            Item { Layout.preferredWidth: Tokens.spacing.sm }
        }

        Rectangle {
            width: parent.width
            height: Tokens.stroke.hairline
            color: Colors.color.outlineVariant
        }

        Repeater {
            id: cells
            model: root.rows
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool _locked: modelData.readable === false || modelData.canRead === false
                readonly property bool _picked: !_locked && Files.selected.indexOf(modelData.path || modelData.uri) >= 0
                readonly property bool _cut: Files.clipboardMode === "cut" && (Files.clipboard || []).indexOf(modelData.path) >= 0
                readonly property bool _held: FilesDrag.active && (FilesDrag.paths || []).indexOf(modelData.path) >= 0
                readonly property bool _land: FilesDrag.active && modelData.dir && FilesDrag.drop === modelData.path && !_held
                opacity: _cut ? Tokens.interaction.cut : (Files.showHidden && String(modelData.name || "").charAt(0) === "." ? Tokens.interaction.hidden : 1)
                width: column.width
                height: Tokens.spacing.xxl + Tokens.spacing.sm
                Accessible.role: Accessible.ListItem
                Accessible.name: row.modelData.name || ""

                HoverHandler { id: rowHover; enabled: !Files.covered }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.small
                    color: row._held || row._land ? Colors.color.primaryContainer
                           : row._picked ? Chrome.navSelected.bg
                           : rowHover.hovered && !row._locked && !Files.covered ? Colors.color.secondaryContainer : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.sm
                    anchors.rightMargin: Tokens.spacing.sm
                    spacing: Tokens.spacing.sm

                    Thumb {
                        entry: row.modelData
                        size: Tokens.icon.md
                        Layout.preferredWidth: Tokens.icon.md
                        Layout.preferredHeight: Tokens.icon.md
                        Layout.alignment: Qt.AlignVCenter
                    }
                    MText {
                        visible: Files.renaming.length === 0 || Files.renaming !== row.modelData.path
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: row._picked ? Chrome.navSelected.fg : Colors.color.onSurface
                        text: row.modelData.name || ""
                    }
                    MTextField {
                        visible: Files.renaming.length > 0 && Files.renaming === row.modelData.path
                        Layout.fillWidth: true
                        text: row.modelData.name || ""
                        selectOnFocus: true
                        onVisibleChanged: if (visible && root.visible) Qt.callLater(focusInput)
                        onAccepted: Files.renameTo(row.modelData.path, text)
                        onEscaped: Files.renaming = ""
                        onActiveFocusChanged: Files.typing = focused
                    }
                    MText {
                        visible: Files.showSize && (Files.place !== "network" || FilesSearch.active)
                        Layout.preferredWidth: facts.colSize
                        horizontalAlignment: Text.AlignRight
                        styleName: "bodySmall"
                        color: row._picked ? Chrome.navSelected.fg : Colors.color.onSurfaceVariant
                        elide: Text.ElideRight
                        text: facts.sizeText(row.modelData)
                    }
                    MText {
                        visible: Files.showCreated && (Files.place !== "network" || FilesSearch.active)
                        Layout.preferredWidth: facts.colDate
                        horizontalAlignment: Text.AlignRight
                        styleName: "bodySmall"
                        color: row._picked ? Chrome.navSelected.fg : Colors.color.onSurfaceVariant
                        elide: Text.ElideRight
                        text: facts.whenText(row.modelData.created)
                    }
                    MText {
                        visible: Files.showModified && (Files.place !== "network" || FilesSearch.active)
                        Layout.preferredWidth: facts.colDate
                        horizontalAlignment: Text.AlignRight
                        styleName: "bodySmall"
                        color: row._picked ? Chrome.navSelected.fg : Colors.color.onSurfaceVariant
                        elide: Text.ElideRight
                        text: facts.whenText(row.modelData.mtime)
                    }
                    MText {
                        visible: Files.showType && (Files.place !== "network" || FilesSearch.active)
                        Layout.preferredWidth: facts.colType
                        horizontalAlignment: Text.AlignRight
                        styleName: "bodySmall"
                        color: row._picked ? Chrome.navSelected.fg : Colors.color.onSurfaceVariant
                        elide: Text.ElideRight
                        text: facts.kindText(row.modelData)
                    }
                }

                FilePress {
                    anchors.fill: parent
                    markRadius: Tokens.radius.small
                    enabled: Files.renaming.length === 0 || Files.renaming !== row.modelData.path
                    entry: row.modelData
                    onMenu: (x, y) => root.menu(row, x, y)
                    onPicked: (extra, range) => FilesSelect.pick(row.modelData.path || row.modelData.uri, extra, range, root.rows)
                    onActivated: root.openRow(row.modelData)
                }
            }
        }
    }

    LandDrop {
        width: root.width
        height: Math.max(column.implicitHeight, root.height)
        z: -1
    }

    Marquee {
        flick: root
        repeater: cells
        onMenu: (x, y) => root._blankMenu(x, y)
    }

    // List clips, so the surrounding margin lives on the pane instead.
    Marquee {
        parent: root.parent
        live: root.visible
        x: root.x - Tokens.spacing.md
        y: root.y - (FilesSearch.active ? 0 : Tokens.spacing.lg)
        width: root.width + Tokens.spacing.md * 2
        height: root.height + Tokens.spacing.md + (FilesSearch.active ? 0 : Tokens.spacing.lg)
        z: -1
        repeater: cells
        onMenu: (x, y) => root._blankMenu(x, y)
    }

    function _blankMenu(x: real, y: real) {
        const kind = root._blankKind();
        if (kind.length)
            Files.openMenu(kind, Files.path, "", x, y);
    }
    function menu(row, x: real, y: real) {
        const id = row.modelData.path || row.modelData.uri;
        const many = !row._locked && FilesSelect.retain(id);
        const name = Files.place === "network" ? String(row.modelData.uri || "") : row.modelData.name;
        Files.openMenu(many ? "selection" : root._kind(row.modelData), row.modelData.path, name, x, y);
    }
    function openRow(entry) {
        if (FilesChoose.active && entry && !entry.dir && FilesChoose.accept(String(entry.path || ""))) return;
        if (Files.place === "network") {
            const path = String(entry.path || "");
            if (path.charAt(0) === "/") Files.go(path, true); else FilesNet.connect(String(entry.uri || ""));
        } else if (Files.place === "trash") FilesTrash.restore(entry.name);
        else if (entry.dir) Files.go(entry.path, true);
        else if (!FilesZip.openZip(entry)) Files.show(entry.path);
    }
    function _kind(entry) {
        if (Files.place === "trash") return "trash";
        if (Files.place === "network") return "share";
        return entry && entry.dir ? "folder" : "file";
    }
    function _blankKind() {
        if (Files.place === "recent") return "recent";
        if (Files.place === "trash") return "trashPlace";
        if (Files.place === "network") return "network";
        if (Files.place !== "folder") return "";
        return "blank";
    }
}
