// Store sidebar: package search + category filters.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

FocusScope {
    id: root

    property Item tabTarget: null

    readonly property var mainCats: {
        void Store.categories;
        const all = Store.categories || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].id !== "installed")
                out.push(all[i]);
        }
        return out;
    }
    readonly property var installedCats: {
        void Store.categories;
        const all = Store.categories || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].id === "installed")
                out.push(all[i]);
        }
        return out;
    }
    readonly property var cats: root.mainCats.concat(root.installedCats)

    signal contentRequested()

    function focusSearch() {
        search.focusToType();
    }

    function focusActive() {
        let idx = root._indexOfActive();
        if (idx < 0)
            idx = 0;
        root._focusRow(idx);
    }

    function goTo(pos: int) {
        const cats = root.cats;
        if (cats.length === 0)
            return;
        const i = Math.max(0, Math.min(cats.length - 1, pos));
        Store.setCategory(cats[i].id);
        root._focusRow(i);
    }

    function move(delta: int) {
        const cats = root.cats;
        if (cats.length === 0)
            return;
        let pos = 0;
        const cur = Store.categoryId;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === cur) {
                pos = i;
                break;
            }
        }
        root.goTo(pos + delta);
    }

    function fromSearchDown() {
        const idx = root._indexOfActive();
        const child = idx >= 0 ? list.itemAt(idx) : null;
        if (child && child.activeFocus) {
            root.move(1);
            return;
        }
        if (idx >= 0) {
            root._focusRow(idx);
            return;
        }
        root.goTo(0);
    }

    function _indexOfActive(): int {
        const id = Store.categoryId;
        const cats = root.cats;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === id)
                return i;
        }
        return -1;
    }

    function _focusRow(idx: int) {
        const child = list.itemAt(idx);
        if (child)
            child.forceActiveFocus();
        list.reveal(child);
    }

    Keys.onPressed: (event) => {
        if (search.focused)
            return;
        if (event.key === Qt.Key_Down) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.goTo(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.goTo(root.cats.length - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.contentRequested();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "store.search"
            KeyNavigation.tab: root.tabTarget
            onTextEdited: Store.setQuery(text)
            onDownPressed: root.fromSearchDown()
            onUpPressed: root.move(-1)
            onAccepted: {
                if (search.text.trim().length > 0) {
                    root.contentRequested();
                    return;
                }
                const idx = root._indexOfActive();
                root.goTo(idx >= 0 ? idx : 0);
            }
            Component.onCompleted: {
                if (Store.query.length > 0)
                    text = Store.query;
            }
        }

        CatList {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            mainCats: root.mainCats
            installedCats: root.installedCats
        }
    }

    Connections {
        target: Store
        function onQueryChanged() {
            if (search.text !== Store.query)
                search.text = Store.query;
        }
    }
}
