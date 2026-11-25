// Settings sidebar: search + grouped nav pills.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

FocusScope {
    id: root

    property var catalog
    property Item tabTarget: null
    property string query: ""
    readonly property var rows: {
        const c = root.catalog;
        if (!c || typeof c.filtered !== "function")
            return [];
        return c.filtered(root.query);
    }

    signal contentRequested()

    function focusSearch() {
        search.focusToType();
        root.revealActive();
    }

    function focusActive() {
        let idx = root._indexOfActive();
        if (idx < 0) {
            const pages = root._pages();
            if (pages.length === 0)
                return;
            idx = pages[0];
        }
        root._focusRow(idx);
        root.revealActive();
    }

    function _pages(): var {
        const rows = root.rows;
        const out = [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].kind !== "group")
                out.push(i);
        }
        return out;
    }

    function _navChild(wrap: var): var {
        if (!wrap)
            return null;
        const kids = wrap.children;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i] && kids[i].variant === "nav")
                return kids[i];
        }
        return null;
    }

    function _focusRow(idx: int) {
        const child = root._navChild(navRepeater.itemAt(idx));
        if (child)
            child.forceActiveFocus();
        root.revealActive();
    }

    function goTo(pos: int) {
        const pages = root._pages();
        if (pages.length === 0)
            return;
        const i = Math.max(0, Math.min(pages.length - 1, pos));
        const row = root.rows[pages[i]];
        if (row && row.id)
            Settings.openAt(row.id, "");
        root._focusRow(pages[i]);
    }

    function move(delta: int) {
        const pages = root._pages();
        if (pages.length === 0)
            return;
        const rows = root.rows;
        let pos = 0;
        const cur = Settings.sectionId;
        for (let i = 0; i < pages.length; i++) {
            if (rows[pages[i]].id === cur) {
                pos = i;
                break;
            }
        }
        root.goTo(pos + delta);
    }

    function fromSearchDown() {
        const idx = root._indexOfActive();
        const child = idx >= 0 ? root._navChild(navRepeater.itemAt(idx)) : null;
        if (child && child.activeFocus) {
            root.move(1);
            return;
        }
        if (idx >= 0) {
            root._focusRow(idx);
            return;
        }
        root.move(0);
    }

    function revealActive() {
        if (root._indexOfActive() < 0 && root.query.length > 0) {
            root.query = "";
            if (search.text.length)
                search.text = "";
        }
        scrollSoon.restart();
    }

    function _indexOfActive(): int {
        const id = Settings.sectionId;
        const rows = root.rows;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind !== "group" && rows[i].id === id)
                return i;
        }
        return -1;
    }

    function _scrollToActive() {
        try {
            if (list.height <= 0)
                return;
            const idx = root._indexOfActive();
            if (idx < 0)
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

    Timer {
        id: scrollSoon
        interval: Math.max(1, Motion.shortMs)
        onTriggered: root._scrollToActive()
    }

    Connections {
        target: Settings
        function onSectionIdChanged() { root.revealActive(); }
        function onOpenChanged() {
            if (Settings.open)
                root.revealActive();
        }
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
            root.goTo(root._pages().length - 1);
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
            placeholderKey: "settings.search"
            KeyNavigation.tab: root.tabTarget
            onTextEdited: root.query = text
            onDownPressed: root.fromSearchDown()
            onUpPressed: root.move(-1)
            onAccepted: {
                const pages = root._pages();
                if (pages.length === 0)
                    return;
                const row = root.rows[pages[0]];
                if (row && row.id)
                    Settings.openAt(row.id, "");
                root._focusRow(pages[0]);
            }
            onEscaped: {
                if (root.query.length === 0)
                    return;
                root.query = "";
                search.text = "";
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
                    model: root.rows.length
                    onItemAdded: (_, item) => {
                        if (item && !item._group && item.rowData && item.rowData.id === Settings.sectionId)
                            scrollSoon.restart();
                    }

                    delegate: Item {
                        id: row
                        required property int index
                        readonly property var rowData: root.rows[index] || ({})
                        readonly property bool _group: row.rowData.kind === "group"
                        Layout.fillWidth: true
                        implicitHeight: row._group
                            ? Tokens.spacing.xl
                            : navItem.implicitHeight
                        Layout.preferredHeight: implicitHeight
                        Layout.topMargin: row._group && row.index > 0
                            ? Tokens.spacing.md
                            : 0
                        Layout.bottomMargin: row._group ? Tokens.spacing.xs : 0

                        MText {
                            visible: row._group
                            anchors.fill: parent
                            key: row.rowData.key || ""
                            styleName: "labelSmall"
                            color: Colors.color.onSurfaceVariant
                            font.capitalization: Font.AllUppercase
                        }

                        MListItem {
                            id: navItem
                            visible: !row._group
                            width: row.width
                            variant: "nav"
                            tabFocus: false
                            iconName: root.catalog.icon(row.rowData.id)
                            titleKey: row._group ? "" : ("settings.sections." + row.rowData.id)
                            badgeCount: row.rowData.id === "system" ? Update.pending.length : 0
                            selected: Settings.sectionId === row.rowData.id
                            onClicked: Settings.openAt(row.rowData.id, "")
                        }
                    }
                }
            }
        }
    }
}
