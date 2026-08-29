import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    property bool _pendingSync: true
    readonly property int columns: 3
    readonly property real contentHeight: layout.implicitHeight

    function moveBy(delta: int) {
        const n = Wallpaper.images.length;
        if (n <= 0)
            return;
        const next = root.currentIndex + delta;
        if (next < 0 || next >= n)
            return;
        root.currentIndex = next;
        root._ensureVisible();
    }

    function activate() {
        const path = Wallpaper.images[root.currentIndex];
        if (path)
            Wallpaper.setWallpaper(path);
    }

    function syncFromCurrent() {
        const paths = Wallpaper.images;
        const pending = Wallpaper.pendingSelect || "";
        if (pending.length > 0) {
            for (let i = 0; i < paths.length; i++) {
                if (paths[i] === pending) {
                    root.currentIndex = i;
                    root._pendingSync = false;
                    Wallpaper.clearPendingSelect();
                    root._ensureVisible();
                    return;
                }
            }
            return;
        }
        const cur = Wallpaper.currentPath;
        for (let i = 0; i < paths.length; i++) {
            if (paths[i] === cur) {
                root.currentIndex = i;
                root._pendingSync = false;
                root._ensureVisible();
                return;
            }
        }
        root.currentIndex = 0;
        if (paths.length > 0)
            root._pendingSync = false;
    }

    function _clamp() {
        const n = Wallpaper.images.length;
        if (n <= 0) {
            root.currentIndex = 0;
            return;
        }
        if (root.currentIndex >= n)
            root.currentIndex = n - 1;
        if (root.currentIndex < 0)
            root.currentIndex = 0;
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
            columnSpacing: Tokens.spacing.sm
            rowSpacing: Tokens.spacing.sm

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
                    current: root.currentIndex === index
                    onClicked: {
                        root.currentIndex = index;
                        Wallpaper.setWallpaper(path);
                    }
                    onHovered: root.currentIndex = index
                }
            }
        }
    }
}
