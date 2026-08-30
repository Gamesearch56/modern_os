// Pill field that opens a menu of MListItems. Not a native combo —
// tokens and motion stay on the kit. `model` is
// [{ value, titleKey?, titleValue?, params? }].
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property var model: []
    property var value: ""
    property string placeholderKey: ""
    property bool enabled: true
    property string query: ""
    property bool allowEmpty: false
    property string emptyValue: ""
    property string emptyKey: "settings.selectNone"

    signal selected(var value)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38

    function _raise(on) {
        const z = on ? 40 : 0;
        root.z = z;
        let p = root.parent;
        const cap = Tokens.spacing.xxl * 8;
        while (p) {
            if (p.height > cap)
                break;
            p.z = z;
            p = p.parent;
        }
    }

    function closeMenu() {
        menu.open = false;
    }

    readonly property bool _searchable: (root.model || []).length > 6
    readonly property var _rows: {
        const base = root.model || [];
        if (!root.allowEmpty)
            return base;
        return [{ value: root.emptyValue, titleKey: root.emptyKey }].concat(base);
    }
    readonly property var _filtered: root._filter(root._rows, root.query)

    function _labelOf(row: var): string {
        if (!row)
            return "";
        if (row.titleKey)
            return I18n.t(row.titleKey, row.params || ({}));
        return row.titleValue || String(row.value || "");
    }

    function _filter(rows: var, needle: string): var {
        const all = rows || [];
        const n = (needle || "").trim().toLowerCase();
        if (n.length === 0)
            return all;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const row = all[i];
            const hay = (root._labelOf(row) + " " + String(row.value || "")).toLowerCase();
            if (hay.indexOf(n) !== -1)
                out.push(row);
        }
        return out;
    }

    readonly property string _label: {
        if (root.allowEmpty && String(root.value ?? "") === String(root.emptyValue))
            return I18n.t(root.emptyKey);
        const rows = root.model || [];
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === String(root.value))
                return root._labelOf(rows[i]);
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        border.color: menu.open ? Colors.color.primary : Colors.color.outline
        border.width: menu.open ? 2 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        spacing: Tokens.spacing.sm

        MText {
            Layout.fillWidth: true
            key: root._label.length === 0 ? root.placeholderKey : ""
            value: root._label
            styleName: "bodyLarge"
            color: root._label.length === 0 ? Colors.color.onSurfaceVariant : Colors.color.onSurface
        }

        MIcon {
            name: menu.open && !menu.opensAbove ? "go-up" : "go-down"
            size: Tokens.icon.sm
            color: Colors.color.onSurfaceVariant
            tint: true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.open = !menu.open
    }

    Keys.onPressed: (event) => {
        if (!menu.open || !root._searchable || search.focused)
            return;
        if (!event.text || event.text.length === 0)
            return;
        search.editor.forceActiveFocus();
        search.text += event.text;
        event.accepted = true;
    }

    MPopup {
        id: menu
        open: false
        elevation: 0
        chromeOpacity: 1
        width: root.width
        implicitHeight: Math.min(
            list.contentHeight
                + Tokens.spacing.md * 2
                + (root._searchable ? Tokens.spacing.xxl + Tokens.spacing.lg : 0),
            Tokens.spacing.xxl * 14)
        z: 80
        onOpenChanged: {
            root._raise(open);
            if (open) {
                SelectMenus.claim(root);
                if (root._searchable) {
                    Qt.callLater(() => {
                        if (menu.open)
                            search.editor.forceActiveFocus();
                    });
                }
                return;
            }
            SelectMenus.release(root);
            root.query = "";
            search.text = "";
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.medium
            color: Colors.color.surface
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MSearchField {
                id: search
                visible: root._searchable
                Layout.fillWidth: true
                placeholderKey: "settings.selectSearch"
                escapeCloses: true
                onTextEdited: root.query = text
                onEscaped: {
                    if (text.length > 0) {
                        text = "";
                        root.query = "";
                    } else {
                        menu.open = false;
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root._filtered.length
                delegate: MListItem {
                    required property int index
                    readonly property var opt: root._filtered[index] || ({})
                    width: list.width
                    titleKey: opt.titleKey || ""
                    titleParams: opt.params || ({})
                    titleValue: opt.titleValue || ""
                    selected: String(opt.value) === String(root.value)
                    onClicked: {
                        root.selected(opt.value);
                        menu.open = false;
                    }
                }
            }
        }
    }
}
