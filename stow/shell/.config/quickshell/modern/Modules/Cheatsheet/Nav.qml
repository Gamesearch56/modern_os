// Category list. Arrows move the selection the same way Settings does:
// the search field captures them, so the window shortcut never sees them.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

FocusScope {
    id: root

    property string categoryId: "applications"
    property Item tabTarget: null
    readonly property var cats: CheatsheetModel.categories(search.text)

    signal queryEdited(string text)
    signal picked(string id)
    signal contentRequested()

    function focusSearch() {
        search.focusToType();
        root.revealActive();
    }

    function focusActive() {
        let idx = root._indexOfActive();
        if (idx < 0)
            idx = 0;
        root._focusRow(idx);
    }

    function goTo(pos: int) {
        const cats = root.cats;
        if (!cats || cats.length === 0)
            return;
        const i = Math.max(0, Math.min(cats.length - 1, pos));
        const id = cats[i] && cats[i].id ? String(cats[i].id) : "";
        if (id.length)
            root.picked(id);
        root._focusRow(i);
    }

    function move(delta: int) {
        const cats = root.cats;
        if (!cats || cats.length === 0)
            return;
        let pos = 0;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === root.categoryId) {
                pos = i;
                break;
            }
        }
        root.goTo(pos + delta);
    }

    function fromSearchDown() {
        const idx = root._indexOfActive();
        const child = idx >= 0 ? navRepeater.itemAt(idx) : null;
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

    function revealActive() {
        scrollSoon.restart();
    }

    function _indexOfActive(): int {
        const cats = root.cats;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === root.categoryId)
                return i;
        }
        return -1;
    }

    function _mark(item: var) {
        const kids = item ? item.children : null;
        if (!kids)
            return;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i] && kids[i].markKeyboard)
                kids[i].markKeyboard();
        }
    }

    function _focusRow(idx: int) {
        const child = navRepeater.itemAt(idx);
        if (!child)
            return;
        child.forceActiveFocus();
        root._mark(child);
        root._scrollTo(idx);
    }

    function _scrollTo(idx: int) {
        try {
            if (list.height <= 0)
                return;
            const item = navRepeater.itemAt(idx);
            if (!item)
                return;
            const pos = item.mapToItem(list.contentItem, 0, 0);
            const top = pos.y;
            const bottom = top + item.height;
            const viewTop = list.contentY;
            const viewBottom = viewTop + list.height;
            const maxY = Math.max(0, list.contentHeight - list.height);
            const pad = Tokens.spacing.md;
            let y = list.contentY;
            if (top < viewTop + pad)
                y = top - pad;
            else if (bottom > viewBottom - pad)
                y = bottom - list.height + pad;
            list.contentY = Math.max(0, Math.min(maxY, y));
        } catch (e) {
        }
    }

    function iconFor(id: string): string {
        switch (id) {
        case "system":
            return "preferences-system";
        case "screenshots":
            return "camera-photo";
        case "windowManagement":
            return "preferences-system-windows";
        case "workspaces":
            return "view-grid";
        case "mouse":
            return "input-mouse";
        default:
            return "view-app-grid-symbolic";
        }
    }

    Timer {
        id: scrollSoon
        interval: Math.max(1, Motion.shortMs)
        onTriggered: {
            const idx = root._indexOfActive();
            if (idx >= 0)
                root._scrollTo(idx);
        }
    }

    onCategoryIdChanged: root.revealActive()

    Keys.onPressed: (event) => {
        if (search.focused)
            return;
        if (event.key === Qt.Key_Down)
            root.move(1);
        else if (event.key === Qt.Key_Up)
            root.move(-1);
        else if (event.key === Qt.Key_Home)
            root.goTo(0);
        else if (event.key === Qt.Key_End)
            root.goTo(root.cats.length - 1);
        else if (event.key === Qt.Key_Right)
            root.contentRequested();
        else
            return;
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "cheatsheet.search"
            KeyNavigation.tab: root.tabTarget
            onTextEdited: root.queryEdited(text)
            onDownPressed: root.fromSearchDown()
            onUpPressed: root.move(-1)
            onAccepted: {
                const idx = root._indexOfActive();
                root.goTo(idx >= 0 ? idx : 0);
            }
            onEscaped: {
                if (search.text.length === 0)
                    return;
                search.text = "";
                root.queryEdited("");
            }
        }

        Flickable {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.xxs

                Repeater {
                    id: navRepeater
                    model: root.cats.length
                    delegate: MListItem {
                        required property int index
                        readonly property var cat: root.cats[index] || ({})
                        Layout.fillWidth: true
                        variant: "nav"
                        tabFocus: false
                        iconName: root.iconFor(cat.id)
                        titleKey: "cheatsheet.category." + cat.id
                        selected: root.categoryId === cat.id
                        onClicked: root.picked(cat.id)
                    }
                }
            }
        }
    }
}
