import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

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

    Connections {
        target: Files
        function onPathChanged() { scroller.contentY = 0; }
        function onPlaceChanged() { scroller.contentY = 0; }
    }

    readonly property int columns: {
        const gap = Tokens.spacing.md;
        const cell = Tokens.window.filesCell + gap;
        const inner = scroller.width;
        return Math.max(1, Math.floor((inner + gap) / cell));
    }

    function reveal(index: int) {
        const item = cells.itemAt(index);
        if (!item)
            return;
        const top = item.y;
        const bottom = top + item.height;
        if (top < scroller.contentY)
            scroller.contentY = top;
        else if (bottom > scroller.contentY + scroller.height)
            scroller.contentY = Math.max(0, bottom - scroller.height);
    }

    onRowsChanged: FilesThumbs.watch(root.rows)
    Component.onCompleted: FilesThumbs.watch(root.rows)
    Component.onDestruction: FilesThumbs.stop()

    BodyScroll {
        flick: scroller
        repeater: cells
        page: root
        mode: "grid"
    }

    FileFacts { id: facts }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(flow.implicitHeight, height)
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: flow
            width: scroller.width
            spacing: Tokens.spacing.md

            Repeater {
                id: cells
                model: root.rows
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property string dates: facts.gridDates(modelData)
                    readonly property string meta: facts.gridMeta(modelData)
                    readonly property string factsText: dates.length && meta.length ? dates + "\n" + meta : (dates || meta)
                    readonly property int factLines: factsText.length > 0 ? factsText.split("\n").length : 0
                    readonly property bool _locked: modelData.readable === false || modelData.canRead === false
                    readonly property bool _picked: !_locked && Files.selected.indexOf(modelData.path || modelData.uri) >= 0
                    readonly property bool _cut: Files.clipboardMode === "cut" && (Files.clipboard || []).indexOf(modelData.path) >= 0
                    readonly property bool _held: FilesDrag.active && (FilesDrag.paths || []).indexOf(modelData.path) >= 0
                    readonly property bool _land: FilesDrag.active && modelData.dir && FilesDrag.drop === modelData.path && !_held
                    opacity: _cut ? Tokens.interaction.cut : (Files.showHidden && String(modelData.name || "").charAt(0) === "." ? Tokens.interaction.hidden : 1)
                    width: Tokens.window.filesCell
                    height: Tokens.spacing.sm * 2 + Tokens.spacing.xxl * 3 + Tokens.spacing.xs + Tokens.spacing.xl
                            + (factLines > 0 ? Tokens.spacing.xs + factLines * Tokens.spacing.lg : 0)
                    clip: true
                    Accessible.role: Accessible.ListItem
                    Accessible.name: cell.modelData.name || ""

                    HoverHandler {
                        id: cellHover
                        enabled: !Files.covered
                        onHoveredChanged: cell._hover(hovered)
                        onPointChanged: if (hovered && FilesHistory.pinHover) cell._hover(true)
                        onEnabledChanged: if (!enabled) cell._hover(false)
                    }
                    function _hover(on) {
                        const id = String(cell.modelData.path || cell.modelData.uri || "");
                        if (!id || (on && !cellHover.enabled))
                            return;
                        if (on && FilesHistory.pinHover && !cell._moved())
                            return;
                        if (on) {
                            Files.hoverPath = id;
                            return;
                        }
                        Qt.callLater(() => { if (Files.hoverPath === id && !(cellHover && cellHover.hovered)) Files.hoverPath = ""; });
                    }
                    function _moved(): bool {
                        const pt = cellHover.point.scenePosition;
                        if (FilesHistory.pinX < 0) {
                            FilesHistory.pinX = pt.x;
                            FilesHistory.pinY = pt.y;
                            return false;
                        }
                        const dx = pt.x - FilesHistory.pinX;
                        const dy = pt.y - FilesHistory.pinY;
                        if (dx * dx + dy * dy < Tokens.spacing.sm * Tokens.spacing.sm)
                            return false;
                        FilesHistory.pinHover = false;
                        FilesHistory.pinX = -1;
                        return true;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.medium
                        color: cell._held || cell._land ? Colors.color.primaryContainer
                            : cell._picked ? Chrome.navSelected.bg
                            : cellHover.hovered && !cell._locked && !Files.covered ? Colors.color.secondaryContainer : "transparent"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.sm
                        spacing: Tokens.spacing.xs
                        Thumb {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Tokens.spacing.xxl * 3
                            frame: true
                            entry: cell.modelData
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: Files.renaming.length === 0 || Files.renaming !== cell.modelData.path
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: cell._picked ? Chrome.navSelected.fg : Colors.color.onSurface
                            text: cell.modelData.name || ""
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: cell.factsText.length > 0 && Files.renaming !== cell.modelData.path
                            horizontalAlignment: Text.AlignHCenter
                            styleName: "bodySmall"
                            color: cell._picked ? Chrome.navSelected.fg : Colors.color.onSurfaceVariant
                            wrapMode: Text.NoWrap
                            maximumLineCount: cell.factLines
                            elide: Text.ElideRight
                            text: cell.factsText
                        }
                        MTextField {
                            Layout.fillWidth: true
                            visible: Files.renaming.length > 0 && Files.renaming === cell.modelData.path
                            text: cell.modelData.name || ""
                            selectOnFocus: true
                            onVisibleChanged: if (visible && root.visible) Qt.callLater(focusInput)
                            onAccepted: Files.renameTo(cell.modelData.path, text)
                            onEscaped: Files.renaming = ""
                            onActiveFocusChanged: Files.typing = focused
                        }
                    }

                    FilePress {
                        anchors.fill: parent
                        enabled: Files.renaming.length === 0 || Files.renaming !== cell.modelData.path
                        entry: cell.modelData
                        onMenu: (x, y) => root.menu(cell, x, y)
                        onPicked: (extra, range) => FilesSelect.pick(cell.modelData.path || cell.modelData.uri, extra, range, root.rows)
                        onActivated: root.activate(cell.modelData)
                    }
                }
            }
        }

        LandDrop {
            width: scroller.width
            height: Math.max(flow.implicitHeight, scroller.height)
            z: -1
        }

        Marquee {
            flick: scroller
            repeater: cells
            onMenu: (x, y) => root._blankMenu(x, y)
        }
    }

    // The pane margin around the icons. The view itself does not clip,
    // so this can sit in the space the layout already leaves.
    Marquee {
        x: -Tokens.spacing.md
        y: FilesSearch.active ? 0 : -Tokens.spacing.lg
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

    function _at(item, x, y) {
        const host = Window.window ? Window.window.contentItem : item;
        return item.mapToItem(host, x, y);
    }

    function menu(cell, x: real, y: real) {
        const id = cell.modelData.path || cell.modelData.uri;
        const many = !cell._locked && FilesSelect.retain(id);
        const kind = many ? "selection" : root._kind(cell.modelData);
        const name = Files.place === "network" ? String(cell.modelData.uri || "") : cell.modelData.name;
        Files.openMenu(kind, cell.modelData.path, name, x, y);
    }

    function _kind(entry) {
        if (Files.place === "trash")
            return "trash";
        if (Files.place === "network")
            return "share";
        return entry && entry.dir ? "folder" : "file";
    }

    function _blankKind() {
        if (Files.place === "recent")
            return "recent";
        if (Files.place === "trash")
            return "trashPlace";
        if (Files.place === "network")
            return "network";
        if (Files.place !== "folder")
            return "";
        return "blank";
    }

    function activate(entry) {
        if (!entry || (FilesChoose.active && !entry.dir && FilesChoose.accept(String(entry.path || ""))))
            return;
        if (Files.place === "network") {
            const path = String(entry.path || "");
            if (path.charAt(0) === "/")
                Files.go(path, true);
            else
                FilesNet.connect(String(entry.uri || ""));
            return;
        }
        if (Files.place === "trash") {
            FilesTrash.restore(entry.name);
            return;
        }
        if (entry.dir)
            Files.go(entry.path, true);
        else if (FilesZip.openZip(entry))
            return;
        else if (entry.readable !== false && entry.canRead !== false)
            Files.show(entry.path);
    }
}
