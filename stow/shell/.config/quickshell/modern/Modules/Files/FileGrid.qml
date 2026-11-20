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
                out.push({ name: nets[i].name || nets[i].path || nets[i].uri, path: nets[i].path || "", uri: nets[i].uri || "", dir: true, size: -1 });
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
        return Math.max(1, Math.floor((scroller.width + gap) / cell));
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
                    readonly property bool _cut: Files.clipboardMode === "cut" && (Files.clipboard || []).indexOf(modelData.path) >= 0
                    readonly property bool _held: FilesDrag.active && (FilesDrag.paths || []).indexOf(modelData.path) >= 0
                    readonly property bool _land: FilesDrag.active && modelData.dir && FilesDrag.drop === modelData.path && !_held
                    opacity: _cut ? Tokens.interaction.cut : 1
                    width: Tokens.window.filesCell
                    height: Tokens.spacing.sm * 2 + Tokens.spacing.xxl * 3 + Tokens.spacing.xs + Tokens.spacing.xl
                            + (factLines > 0 ? Tokens.spacing.xs + factLines * Tokens.spacing.lg : 0)
                    clip: true
                    Accessible.role: Accessible.ListItem
                    Accessible.name: cell.modelData.name || ""

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.medium
                        color: cell._held || cell._land ? Colors.color.primaryContainer
                            : !cell._locked && Files.selected.indexOf(cell.modelData.path || cell.modelData.uri) >= 0 ? Colors.color.secondaryContainer : "transparent"
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
                            visible: Files.renaming !== cell.modelData.path
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: cell.modelData.name || ""
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: cell.factsText.length > 0 && Files.renaming !== cell.modelData.path
                            horizontalAlignment: Text.AlignHCenter
                            styleName: "bodySmall"
                            color: Colors.color.onSurfaceVariant
                            wrapMode: Text.NoWrap
                            maximumLineCount: cell.factLines
                            elide: Text.ElideRight
                            text: cell.factsText
                        }
                        MTextField {
                            Layout.fillWidth: true
                            visible: Files.renaming === cell.modelData.path
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
                        enabled: Files.renaming !== cell.modelData.path
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

        MouseArea {
            id: blank
            width: scroller.width
            height: Math.max(flow.implicitHeight, scroller.height)
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        focus: true
        z: -1
        onPressed: forceActiveFocus()
        onClicked: (mouse) => {
            if (Files._holdSelect)
                return;
            Files.clearSelection();
            if (mouse.button !== Qt.RightButton)
                return;
            const kind = root._blankKind();
            if (!kind.length)
                return;
            const at = root._at(blank, mouse.x, mouse.y);
            Files.openMenu(kind, Files.path, "", at.x, at.y);
        }
        }
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
            return "net";
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
        if (!entry)
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
