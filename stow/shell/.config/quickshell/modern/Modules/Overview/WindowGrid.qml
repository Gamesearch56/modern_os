import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    readonly property int columns: Math.max(1, Math.floor(Math.max(width, 1) / (Tokens.spacing.xxl * 7)))
    readonly property var windows: {
        void Hypr.toplevelList;
        const all = Hypr.toplevelList || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const t = all[i];
            if (!Hypr.isWorkspaceToplevel(t))
                continue;
            out.push(t);
        }
        return out;
    }
    readonly property int count: (root.windows || []).length

    function moveBy(delta: int) {
        const n = root.count;
        if (n <= 0)
            return;
        root.currentIndex = ((root.currentIndex + delta) % n + n) % n;
        root._ensureVisible();
    }

    function activate() {
        const tile = tiles.itemAt(root.currentIndex);
        if (!tile || !tile.address)
            return;
        Hypr.activateWindow(tile.address);
        Overview.hide();
    }

    function _ensureVisible() {
        const tile = tiles.itemAt(root.currentIndex);
        if (!tile || flick.height <= 0)
            return;
        const top = tile.y;
        const bottom = tile.y + tile.height;
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top);
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height);
    }

    function _icon(win: var): string {
        const ipc = win?.lastIpcObject || ({});
        return Apps.resolveIcon(String(ipc.class || win?.class || ipc.initialClass || ""));
    }

    function _title(win: var): string {
        const ipc = win?.lastIpcObject || ({});
        return String(win?.title || ipc.title || ipc.class || "");
    }

    function _subtitle(win: var): string {
        const ipc = win?.lastIpcObject || ({});
        const raw = win?.workspace?.id ?? ipc.workspace?.id ?? ipc.workspace;
        const id = Number(raw);
        if (id > 0)
            return I18n.t("overview.workspace", { id: id });
        return "";
    }

    onCountChanged: {
        if (root.currentIndex >= root.count)
            root.currentIndex = Math.max(0, root.count - 1);
    }

    MEmptyState {
        visible: root.count === 0
        anchors.fill: parent
        iconName: "view-pages-overview"
        titleKey: "overview.empty"
        hintKey: "overview.emptyHint"
    }

    Flickable {
        id: flick
        visible: root.count > 0
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: layout
            width: flick.width
            columns: root.columns
            columnSpacing: Tokens.spacing.md
            rowSpacing: Tokens.spacing.md

            Repeater {
                id: tiles
                model: root.count
                delegate: MWindowTile {
                    required property int index
                    readonly property var win: (root.windows || [])[index]
                    readonly property string address: win?.address || ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: (layout.width - layout.columnSpacing * Math.max(0, root.columns - 1)) / root.columns
                    Layout.preferredHeight: Tokens.spacing.xxl * 7
                    iconName: root._icon(win)
                    titleValue: root._title(win)
                    subtitleValue: root._subtitle(win)
                    selected: root.currentIndex === index
                    onHovered: root.currentIndex = index
                    onClicked: {
                        root.currentIndex = index;
                        root.activate();
                    }
                }
            }
        }
    }
}
