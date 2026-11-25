import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Manual sidebar: search over titles and full text, then the documents
// of the user manual and the technical reference, each in its sections.
FocusScope {
    id: root

    property string current: ""
    property string query: ""
    readonly property bool searching: search.focused
    readonly property var docs: ManualDocs.search(root.query)
    readonly property var rows: {
        const out = [];
        const groups = ["manual", "reference"];
        for (let g = 0; g < groups.length; g++) {
            const items = root.docs.filter(d => d.group === groups[g]);
            if (!items.length)
                continue;
            out.push({ kind: "part", key: "manual.groups." + groups[g] });
            let section = "";
            for (let i = 0; i < items.length; i++) {
                if (items[i].section !== section) {
                    section = String(items[i].section || "more");
                    out.push({ kind: "section", key: "manual.sections." + section });
                }
                out.push({ kind: "doc", path: items[i].path, title: items[i].title, number: Number(items[i].number || 0) });
            }
        }
        return out;
    }

    signal picked(string path)
    signal contentRequested()

    function focusSearch() {
        search.focusToType();
    }

    function focusActive() {
        const idx = root._indexOf(root.current);
        const item = repeater.itemAt(idx >= 0 ? idx : root._docRows()[0] ?? -1);
        if (item)
            item.navItem.forceActiveFocus();
    }

    function _docRows(): var {
        const out = [];
        for (let i = 0; i < root.rows.length; i++) {
            if (root.rows[i].kind === "doc")
                out.push(i);
        }
        return out;
    }

    function _indexOf(path: string): int {
        for (let i = 0; i < root.rows.length; i++) {
            if (root.rows[i].kind === "doc" && root.rows[i].path === path)
                return i;
        }
        return -1;
    }

    function move(delta: int) {
        const docs = root._docRows();
        if (!docs.length)
            return;
        const pos = docs.indexOf(root._indexOf(root.current));
        const next = docs[Math.max(0, Math.min(docs.length - 1, pos < 0 ? 0 : pos + delta))];
        root.picked(root.rows[next].path);
        const item = repeater.itemAt(next);
        if (!item)
            return;
        item.navItem.forceActiveFocus();
        if (item.y < list.contentY)
            list.contentY = item.y;
        else if (item.y + item.height > list.contentY + list.height)
            list.contentY = item.y + item.height - list.height;
    }

    Keys.onPressed: (event) => {
        if (search.focused)
            return;
        if (event.key === Qt.Key_Down)
            root.move(1);
        else if (event.key === Qt.Key_Up)
            root.move(-1);
        else if (event.key === Qt.Key_Right)
            root.contentRequested();
        else
            return;
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "manual.search"
            onTextEdited: root.query = text
            onDownPressed: root.focusActive()
            onAccepted: {
                const docs = root._docRows();
                if (docs.length)
                    root.picked(root.rows[docs[0]].path);
            }
            onEscaped: {
                root.query = "";
                search.text = "";
            }
        }

        MText {
            visible: root.rows.length === 0 && !ManualDocs.loading
            Layout.fillWidth: true
            key: "manual.noResults"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        Flickable {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Accessible.role: Accessible.List
            Accessible.name: I18n.t("manual.contents")

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.xxs

                Repeater {
                    id: repeater
                    model: root.rows.length

                    delegate: NavRow {
                        rowData: root.rows[index] || ({})
                        selected: rowData.kind === "doc" && rowData.path === root.current
                        onClicked: root.picked(rowData.path)
                    }
                }
            }
        }
    }
}
