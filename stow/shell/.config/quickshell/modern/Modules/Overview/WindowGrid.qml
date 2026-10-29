import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
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
    readonly property int columns: Math.min(3, Math.max(1, root.count))
    readonly property real tileWidth: {
        const gap = Tokens.recents.gap;
        const boxW = root.width > 0 ? root.width : Tokens.window.overviewWidth;
        const availW = Math.max(1, boxW - Tokens.recents.inset * 2);
        return Math.max(Tokens.recents.wellHeight, (availW - gap * 2) / 3);
    }
    readonly property real tileHeight: {
        const ratio = Tokens.recents.cardHeight / Math.max(1, Tokens.recents.cardWidth);
        return Math.max(Tokens.recents.wellHeight, root.tileWidth * ratio);
    }
    implicitHeight: {
        if (root.count === 0)
            return Tokens.recents.cardHeight;
        return layout.implicitHeight + Tokens.recents.insetY * 2;
    }

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
        const top = layout.y + tile.y;
        const bottom = top + tile.height;
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top);
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height);
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
        contentHeight: holder.height
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: holder
            width: flick.width
            height: layout.implicitHeight + Tokens.recents.insetY * 2

            GridLayout {
                id: layout
                anchors.centerIn: parent
                columns: root.columns
                columnSpacing: Tokens.recents.gap
                rowSpacing: Tokens.recents.gap

                Repeater {
                    id: tiles
                    model: root.count
                    delegate: Tile {
                        required property int index
                        win: (root.windows || [])[index]
                        Layout.preferredWidth: root.tileWidth
                        Layout.preferredHeight: root.tileHeight
                        Layout.fillWidth: false
                        Layout.fillHeight: false
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
}
