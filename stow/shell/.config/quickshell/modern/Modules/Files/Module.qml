// ModernOS File Manager. The window only composes the panes.
import Quickshell
import QtQuick
import QtQuick.Layouts as Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: mod
    property var _fileBus: FilesBus
    // A fast folder should not flash a bar. Show it only once the work
    // has already outlasted a normal listing.
    property bool _slow: false
    LazyLoader {
        active: Files.open

        FloatingWindow {
            id: win
            visible: Files.open
            title: "modern.files"
            color: "transparent"
            implicitWidth: Tokens.window.filesWidth
            implicitHeight: Tokens.window.filesHeight
            Component.onCompleted: {
                if (implicitWidth > 0)
                    width = implicitWidth;
            }

            MWindowShell {
                anchors.fill: parent
                titleKey: "files.title"
                trailingFill: true
                onClosed: Files.hide()

                trailing: Toolbar { loading: mod._slow }

                Layouts.RowLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MPane {
                        Layouts.Layout.preferredWidth: Tokens.window.filesPlaces
                        Layouts.Layout.fillHeight: true

                        Places {
                            anchors.fill: parent
                        }
                    }

                    Item {
                        Layouts.Layout.fillWidth: true
                        Layouts.Layout.fillHeight: true

                        TabStrip {
                            id: tabs
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                        }
                        Breadcrumb {
                            id: crumbs
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: tabs.bottom
                            anchors.topMargin: crumbs._shown && tabs.visible ? Tokens.spacing.sm : 0
                            height: crumbs._shown ? Tokens.spacing.xxl : 0
                        }
                        Item {
                            id: body
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: crumbs.bottom
                            anchors.topMargin: Tokens.spacing.lg
                            anchors.bottom: parent.bottom

                            Row {
                                id: searchHead
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: FilesSearch.active ? implicitHeight : 0
                                opacity: FilesSearch.active ? 1 : 0
                                spacing: Tokens.spacing.md
                                MText {
                                    width: Math.max(0, searchHead.width - found.implicitWidth - searchHead.spacing)
                                    key: "files.search.heading"
                                    params: ({ query: FilesSearch.query })
                                    styleName: "titleSmall"
                                    color: Colors.color.onSurfaceVariant
                                    elide: Text.ElideRight
                                }
                                MText {
                                    id: found
                                    key: "files.search.found"
                                    params: ({ count: (FilesSearch.results || []).length })
                                    styleName: "titleSmall"
                                }
                            }

                            FileGrid {
                                id: fileGrid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: searchHead.bottom
                                anchors.bottom: parent.bottom
                                visible: Files.view === "grid"
                            }
                            List {
                                id: fileList
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: searchHead.bottom
                                anchors.bottom: parent.bottom
                                visible: Files.view === "list"
                            }
                            MText {
                                anchors.centerIn: parent
                                enabled: false
                                key: Files.place === "network" ? "files.networkEmpty" : Files.place === "favorites" ? "files.favoritesEmpty" : Files.place === "recent" ? "files.recentEmpty" : "files.emptyDir"
                                visible: !Files.busy && !FilesSearch.running && !FilesSearch.active && (
                                    (Files.place === "folder" && (Files.entries || []).length === 0)
                                    || (Files.place === "network" && (FilesPlaces.mounts || []).length === 0)
                                    || (Files.place === "favorites" && FilesPlaces.favoriteRows(Config.files.favorites).length === 0)
                                    || (Files.place === "recent" && (FilesPlaces.recent || []).length === 0)
                                )
                            }
                        }
                    }
                }
            }

            Shortcuts {}
            ArrowKeys {
                rows: Files.view === "grid" ? fileGrid.rows : fileList.rows
                columns: Files.view === "grid" ? fileGrid.columns : 1
                view: Files.view === "grid" ? fileGrid : fileList
            }
            TapHandler {
                parent: win.contentItem
                acceptedButtons: Qt.BackButton
                onTapped: if (mod._mouseNav()) Files.back()
            }
            TapHandler {
                parent: win.contentItem
                acceptedButtons: Qt.ForwardButton
                onTapped: if (mod._mouseNav()) Files.forward()
            }
            ContextMenu {}
            Properties {}
            Confirm {}
            NamePrompt {}
        }
    }

    Timer {
        id: lag
        interval: Motion.longMs
        onTriggered: mod._slow = mod._pending()
    }

    function _mouseNav(): bool {
        return Files.open && !Files.propertiesOpen && !Files.confirming && !Files.naming
            && !Files.menuOpen && Storage.confirmWhere !== "files";
    }

    function _pending(): bool {
        return Files.busy || FilesSearch.running || FilesSizes.running;
    }

    function _watch() {
        if (!mod._pending()) {
            lag.stop();
            mod._slow = false;
            return;
        }
        if (!mod._slow && !lag.running)
            lag.start();
    }

    // A new place starts its own wait. The bar from the folder just
    // left must not stay up while the next one loads.
    function _leave() {
        FilesSizes.stop();
        FilesSearch.stop();
        mod._slow = false;
        lag.stop();
        mod._watch();
    }

    function _measure() {
        if (!Files.open || Files.place !== "folder" || !Files.showSize || !Files.path.length) {
            FilesSizes.stop();
            return;
        }
        FilesSizes.start(Files.path, Files.showHidden);
    }

    function _applySizes(folder: string, sizes: var) {
        if (Files.place !== "folder" || Files.path !== folder || !sizes)
            return;
        const rows = (Files.entries || []).slice();
        let changed = false;
        for (let i = 0; i < rows.length; i++) {
            const size = sizes[rows[i].path];
            if (size === undefined || Number(rows[i].size) === Number(size))
                continue;
            rows[i] = Object.assign({}, rows[i], { size: size });
            changed = true;
        }
        if (!changed)
            return;
        Files.entries = Files.sortKey === "size" ? mod._orderSize(rows) : rows;
    }

    function _orderSize(rows: var): var {
        const desc = Files.sortDesc !== false;
        function cmp(a, b) {
            const d = Number(a.size) - Number(b.size);
            if (d !== 0)
                return desc ? (d > 0 ? -1 : 1) : (d > 0 ? 1 : -1);
            const an = String(a.name || "").toLowerCase();
            const bn = String(b.name || "").toLowerCase();
            return an < bn ? -1 : (an > bn ? 1 : 0);
        }
        if (!Files.foldersFirst)
            return rows.slice().sort(cmp);
        const dirs = [];
        const files = [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].dir)
                dirs.push(rows[i]);
            else
                files.push(rows[i]);
        }
        dirs.sort(cmp);
        files.sort(cmp);
        return dirs.concat(files);
    }

    Connections {
        target: Files
        function onPathChanged() {
            FilesTabs.follow(Files.path);
            mod._leave();
        }
        function onPlaceChanged() { mod._leave(); }
        function onListed() { mod._measure(); }
        function onShowSizeChanged() { mod._measure(); }
        function onBusyChanged() { mod._watch(); }
        function onOpenedFile(path) { FilesPlaces.record(path); }
        function onFailed(reason) {
            const denied = String(reason || "") === "denied";
            Notifications.toast(I18n.t(denied ? "files.noAccess" : "files.refused"), "");
        }
        function onOpenChanged() {
            if (!Files.open)
                FilesSizes.stop();
            else {
                Storage.watching = true;
                FilesPlaces.reload();
            }
            mod._watch();
        }
    }

    Connections {
        target: FilesSearch
        function onRunningChanged() { mod._watch(); }
    }

    Connections {
        target: FilesSizes
        function onRunningChanged() { mod._watch(); }
        function onBatch(folder, sizes) { mod._applySizes(folder, sizes); }
    }

    Connections {
        target: FilesPlaces
        function onMounted(path) { Files.go(path, true); }
    }

    Connections {
        target: FilesTrash
        function onChanged() { Files.refresh(); }
        function onFailed(reason) { Files.failed(reason); }
    }
}
