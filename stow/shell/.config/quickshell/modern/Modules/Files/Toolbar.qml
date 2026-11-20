import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    id: root
    property bool loading: false
    anchors.fill: parent
    spacing: Tokens.spacing.xs

    MIconButton { iconName: "go-previous"; key: "files.toolbar.back"; tip: true; enabled: FilesHistory.back.length > 0; onClicked: Files.back() }
    MIconButton { iconName: "go-next"; key: "files.toolbar.forward"; tip: true; enabled: FilesHistory.forward.length > 0; onClicked: Files.forward() }
    MIconButton { iconName: "go-up"; key: "files.toolbar.up"; tip: true; onClicked: Files.up() }

    MTextField {
        id: search
        Layout.fillWidth: true
        placeholderKey: "files.search.placeholder"
        captureEscape: true
        selectAllOnPress: search.text === root.locationText()
        captureReturn: true
        captureArrows: !root._quiet && root._query().length > 0
        onTextEdited: root._type()
        onActiveFocusChanged: {
            if (search.focused) root._leaveField = false;
            const menu = suggest.open && !root._leaveField;
            Files.typing = search.focused || menu;
            if (menu && !search.focused)
                Qt.callLater(() => { if (suggest.open && !root._leaveField) search.forceActiveFocus(); });
            root._sync();
        }
        onUpPressed: root._move(-1)
        onDownPressed: root._move(1)
        onAccepted: root._submit()
        onEscaped: {
            if (suggest.open || FilesSearch.popup) {
                root._closeQuick();
                return;
            }
            root._dropField();
        }

        Suggest {
            id: suggest
            span: search.width
            rows: root.suggestions
            index: root._index
            onChosen: (at) => { root._index = at; root._accept(); root._closeQuick(); root._dropField(); }
        }

        LoadingBar {
            enabled: false; z: 11; active: root.loading
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.spacing.lg; anchors.rightMargin: Tokens.spacing.lg
            anchors.bottomMargin: Tokens.spacing.xs
        }

        // Hold and drag the path to move the window. A click still edits it.
        MTitleDrag {
            anchors.fill: parent
            z: 10
            cursor: Qt.IBeamCursor
            threshold: Tokens.spacing.sm
            onClicked: {
                search.forceActiveFocus();
                if (search.text === root.locationText())
                    search.editor.selectAll();
            }
        }
    }

    Timer {
        id: hunt
        interval: Motion.shortMs
        onTriggered: {
            if (!root._query().length)
                return;
            FilesSearch.start(Files.path, search.text, Files.showHidden);
        }
    }

    Timer {
        id: reveal
        interval: Motion.mediumMs
        onTriggered: {
            if (root._quiet || !search.focused || !root.suggestions.length)
                return;
            suggest.open = true;
            FilesSearch.popup = true;
        }
    }

    SearchScope {}

    MIconButton {
        id: sortButton
        iconName: "view-sort-ascending"
        key: "files.toolbar.sort"; tip: true
        onClicked: sortMenu.open = !sortMenu.open
        SortMenu { id: sortMenu }
    }
    MIconButton {
        iconName: "settings-configure"
        key: "files.toolbar.details"; tip: true
        onClicked: detailsMenu.open = !detailsMenu.open
        DetailsMenu { id: detailsMenu }
    }
    MIconButton {
        iconName: Files.view === "grid" ? "view-list-symbolic" : "view-grid-symbolic"
        key: Files.view === "grid" ? "files.view.list" : "files.view.grid"; tip: true
        onClicked: Files.setView(Files.view === "grid" ? "list" : "grid")
    }
    MIconButton {
        iconName: "utilities-terminal"
        key: "files.toolbar.terminal"; tip: true
        onClicked: {
            FilesPlaces.openTerminal(Files.path);
            Files.hide();
        }
    }

    Connections {
        target: Files
        function onSearchOpenChanged() {
            if (!Files.searchOpen) return;
            root.showLocation();
            Qt.callLater(() => { search.forceActiveFocus(); Qt.callLater(() => search.editor.selectAll()); });
        }
        function onPathChanged() { if (!search.focused) root.showLocation(); }
        function onSelectedChanged() { if (!search.focused) root.showLocation(); }
        function onPlaceChanged() { if (!search.focused) root.showLocation(); }
    }

    Connections {
        target: FilesSearch
        function onResultsChanged() { root._sync(); }
        function onDismiss() { root._closeQuick(); }
        function onCleared() { root._leaveSearch(); }
        function onReleased() { root._dropField(); }
    }

    Component.onCompleted: root.showLocation()

    property bool _hold: false
    property bool _quiet: false
    property bool _leaveField: false
    property int _index: -1
    readonly property int _limit: 8
    readonly property var suggestions: {
        void [search.text, search.focused, root._hold, FilesSearch.results, Files.entries, Files.foldersFirst, Files.place, Files.selected];
        return root._collect();
    }

    SearchRank { id: rank }

    onSuggestionsChanged: {
        if (root._index >= root.suggestions.length)
            root._index = root.suggestions.length - 1;
        root._sync();
    }

    function locationText(): string {
        return Files.selected.length === 1 ? String(Files.selected[0] || "") : (Files.path || "");
    }

    function showLocation() {
        const next = root.locationText();
        if (search.text === next)
            return;
        root._hold = true;
        search.text = next;
        root._hold = false;
    }

    function _query(): string {
        if (!search.focused || root._hold)
            return "";
        const text = String(search.text || "").trim();
        if (text.length < 3 || text === root.locationText())
            return "";
        return text;
    }

    function _type() {
        if (root._hold)
            return;
        root._quiet = false;
        root._index = -1;
        if (!root._query().length) {
            hunt.stop();
            FilesSearch.stop();
            root._index = -1;
            root._sync();
            return;
        }
        hunt.restart();
        root._sync();
    }

    function _move(delta: int) {
        if (root._quiet)
            return;
        const rows = root.suggestions;
        if (!rows.length)
            return;
        let at = root._index;
        if (at < 0)
            at = delta < 0 ? rows.length - 1 : 0;
        else
            at = Math.max(0, Math.min(rows.length - 1, at + delta));
        root._index = at;
        suggest.open = true;
        FilesSearch.popup = true;
    }

    function _accept() {
        const rows = root.suggestions;
        if (!rows.length)
            return;
        const row = rows[root._index < 0 ? 0 : root._index];
        if (!row || !row.path)
            return;
        hunt.stop();
        FilesSearch.stop();
        root._index = -1;
        const path = String(row.path);
        const slash = path.lastIndexOf("/");
        const parent = slash > 0 ? path.slice(0, slash) : "/";
        Files.go(parent, true, [path]);
        root.showLocation();
        root._sync();
    }

    function _submit() {
        const picked = (suggest.open || FilesSearch.popup) && root._index >= 0;
        const text = String(search.text || "").trim();
        const here = text !== root.locationText();
        const keep = !picked && here && text === FilesSearch.query;
        if (picked) root._accept();
        else hunt.stop();
        root._closeQuick();
        if (keep) FilesSearch.openPage();
        else if (!picked && here && text.length)
            FilesSearch.start(Files.path, text, Files.showHidden, true);
        root._dropField();
    }

    function _dropField() {
        root._leaveField = true;
        search.editor.deselect(); root.forceActiveFocus();
    }

    function _leaveSearch() {
        hunt.stop();
        FilesSearch.stop();
        root._quiet = true;
        root._index = -1;
        Files.searchOpen = false;
        root.showLocation();
        root._sync();
    }

    function _closeQuick() {
        reveal.stop();
        root._quiet = true;
        root._index = -1;
        suggest.open = false;
        FilesSearch.popup = false;
    }

    function _sync() {
        const show = !root._quiet && search.focused && root.suggestions.length > 0;
        if (!show) {
            reveal.stop();
            suggest.open = false;
            FilesSearch.popup = false;
        } else if (!suggest.open && !reveal.running)
            reveal.start();
    }

    function _collect() {
        return rank.collect(
            root._query(), FilesSearch.results, Files.entries,
            Files.path, Files.place, Files.foldersFirst, root._limit);
    }
}
