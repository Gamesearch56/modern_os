import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    property bool _pendingSync: true

    signal removeRequested(string path)
    readonly property int columns: 3
    readonly property real contentHeight: layout.implicitHeight

    function _selectable(i: int): bool {
        const paths = Wallpaper.images;
        if (i < 0 || i >= paths.length)
            return false;
        return paths[i] !== Wallpaper.currentPath;
    }

    function _scan(from: int, step: int): int {
        const n = Wallpaper.images.length;
        for (let i = from; i >= 0 && i < n; i += step)
            if (root._selectable(i))
                return i;
        return -1;
    }

    function moveBy(delta: int) {
        const n = Wallpaper.images.length;
        if (n <= 0 || delta === 0)
            return;
        if (!root._selectable(root.currentIndex)) {
            const found = root._scan(delta > 0 ? 0 : n - 1, delta > 0 ? 1 : -1);
            if (found >= 0) {
                root.currentIndex = found;
                root._ensureVisible();
            }
            return;
        }
        let next = root.currentIndex + delta;
        while (next >= 0 && next < n) {
            if (root._selectable(next)) {
                root.currentIndex = next;
                root._ensureVisible();
                return;
            }
            next += delta;
        }
    }

    function activate() {
        const path = Wallpaper.images[root.currentIndex];
        if (path && path !== Wallpaper.currentPath)
            Wallpaper.setWallpaper(path);
    }

    function syncFromCurrent() {
        const paths = Wallpaper.images;
        const pending = Wallpaper.pendingSelect || "";
        if (pending.length > 0) {
            for (let i = 0; i < paths.length; i++) {
                if (paths[i] === pending && root._selectable(i)) {
                    root.currentIndex = i;
                    root._pendingSync = false;
                    Wallpaper.clearPendingSelect();
                    root._ensureVisible();
                    return;
                }
            }
            Wallpaper.clearPendingSelect();
        }
        let start = 0;
        const cur = Wallpaper.currentPath;
        for (let i = 0; i < paths.length; i++) {
            if (paths[i] === cur) {
                start = i + 1;
                break;
            }
        }
        let idx = root._scan(start, 1);
        if (idx < 0)
            idx = root._scan(0, 1);
        root.currentIndex = idx;
        if (paths.length > 0)
            root._pendingSync = false;
        if (idx >= 0)
            root._ensureVisible();
    }

    function _clamp() {
        const n = Wallpaper.images.length;
        if (n <= 0) {
            root.currentIndex = -1;
            return;
        }
        if (root.currentIndex >= n)
            root.currentIndex = n - 1;
        if (!root._selectable(root.currentIndex)) {
            let i = root._scan(root.currentIndex + 1, 1);
            if (i < 0)
                i = root._scan(root.currentIndex - 1, -1);
            root.currentIndex = i;
        }
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

    Connections {
        target: Wallpaper
        function onImagesChanged() {
            root._clamp();
            if (root._pendingSync || (Wallpaper.pendingSelect || "").length > 0)
                root.syncFromCurrent();
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: layout
            width: flick.width
            columns: root.columns
            columnSpacing: Tokens.spacing.xxs
            rowSpacing: Tokens.spacing.xxs

            Repeater {
                id: tiles
                model: Wallpaper.images
                delegate: MImageTile {
                    required property int index
                    required property var modelData
                    readonly property string path: String(modelData || "")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: (layout.width - layout.columnSpacing * Math.max(0, root.columns - 1)) / root.columns
                    Layout.preferredHeight: Tokens.spacing.xxl * 7
                    Layout.columnSpan: tiles.count === 1 ? root.columns : 1
                    source: path.length > 0 ? ("file://" + path) : ""
                    selected: path === Wallpaper.currentPath
                    current: root.currentIndex === index && path !== Wallpaper.currentPath
                    removable: Wallpaper.canRemove(path)
                    onClicked: {
                        if (path === Wallpaper.currentPath)
                            return;
                        root.currentIndex = index;
                        Wallpaper.setWallpaper(path);
                    }
                    onHovered: {
                        if (path !== Wallpaper.currentPath)
                            root.currentIndex = index;
                    }
                    onRemoveClicked: root.removeRequested(path)
                }
            }
        }
    }
}
