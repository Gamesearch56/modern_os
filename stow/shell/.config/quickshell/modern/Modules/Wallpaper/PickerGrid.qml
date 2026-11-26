import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    property bool _pendingSync: true
    property bool _pointerArmed: false
    property bool _swallowMove: true

    signal removeRequested(string path)
    readonly property int columns: 3
    readonly property real _gap: Tokens.spacing.xxs
    readonly property real _tileH: Tokens.spacing.xxl * 7
    readonly property real contentHeight: grid.contentHeight

    function _inRange(i: int): bool {
        return i >= 0 && i < Wallpaper.images.length;
    }

    function moveBy(delta: int) {
        const n = Wallpaper.images.length;
        if (n <= 0 || delta === 0)
            return;
        root._pointerArmed = false;
        if (!root._inRange(root.currentIndex)) {
            root.currentIndex = delta > 0 ? 0 : n - 1;
            root._ensureVisible();
            return;
        }
        const next = root.currentIndex + delta;
        if (!root._inRange(next))
            return;
        root.currentIndex = next;
        root._ensureVisible();
    }

    function activate() {
        const path = Wallpaper.images[root.currentIndex];
        if (path && path !== Wallpaper.currentPath)
            Wallpaper.setWallpaper(path);
    }

    function resetSelection() {
        root._pointerArmed = false;
        root._swallowMove = true;
        const n = Wallpaper.images.length;
        root.currentIndex = n > 0 ? 0 : -1;
        root._pendingSync = false;
        Wallpaper.clearPendingSelect();
        grid.positionViewAtBeginning();
    }

    function _clamp() {
        const n = Wallpaper.images.length;
        if (n <= 0) {
            root.currentIndex = -1;
            return;
        }
        if (root.currentIndex < 0)
            root.currentIndex = 0;
        else if (root.currentIndex >= n)
            root.currentIndex = n - 1;
    }

    function _ensureVisible() {
        if (!root._inRange(root.currentIndex) || grid.height <= 0)
            return;
        grid.positionViewAtIndex(root.currentIndex, GridView.Contain);
    }

    function _hoverAt(index: int, moved: bool) {
        if (!root._inRange(index))
            return;
        if (moved) {
            if (root._swallowMove) {
                root._swallowMove = false;
                return;
            }
            root._pointerArmed = true;
        }
        if (!root._pointerArmed)
            return;
        root.currentIndex = index;
    }

    Connections {
        target: Wallpaper
        function onImagesChanged() {
            if (root._pendingSync) {
                root.resetSelection();
                return;
            }
            root._clamp();
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        cellWidth: count === 1 ? width : Math.max(1, Math.floor(width / root.columns))
        cellHeight: root._tileH + root._gap
        cacheBuffer: cellHeight * 3
        reuseItems: true
        model: Wallpaper.images
        highlightFollowsCurrentItem: false
        keyNavigationEnabled: false
        interactive: true

        delegate: Item {
            id: cell
            required property int index
            required property var modelData
            readonly property string path: String(modelData || "")
            width: grid.cellWidth
            height: grid.cellHeight

            MImageTile {
                anchors.fill: parent
                anchors.rightMargin: (grid.count === 1 || (cell.index % root.columns) === root.columns - 1) ? 0 : root._gap
                anchors.bottomMargin: root._gap
                source: {
                    void Wallpaper.thumbsRev;
                    return cell.path.length > 0 ? Wallpaper.tileSource(cell.path) : "";
                }
                selected: cell.path === Wallpaper.currentPath
                current: root.currentIndex === cell.index
                hoverRing: false
                removable: Wallpaper.canRemove(cell.path)
                onClicked: {
                    if (cell.path === Wallpaper.currentPath)
                        return;
                    root.currentIndex = cell.index;
                    Wallpaper.setWallpaper(cell.path);
                }
                onHovered: root._hoverAt(cell.index, false)
                onPointerMoved: root._hoverAt(cell.index, true)
                onRemoveClicked: root.removeRequested(cell.path)
                onImageFailed: Wallpaper.tileFailed(cell.path)
            }
        }
    }
}
