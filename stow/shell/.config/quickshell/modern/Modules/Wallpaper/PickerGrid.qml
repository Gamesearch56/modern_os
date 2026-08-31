import QtQuick
import QtQuick.Layouts
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
    readonly property real contentHeight: layout.implicitHeight

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
        flick.contentY = 0;
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
                    current: root.currentIndex === index
                    hoverRing: false
                    removable: Wallpaper.canRemove(path)
                    onClicked: {
                        if (path === Wallpaper.currentPath)
                            return;
                        root.currentIndex = index;
                        Wallpaper.setWallpaper(path);
                    }
                    onHovered: root._hoverAt(index, false)
                    onPointerMoved: root._hoverAt(index, true)
                    onRemoveClicked: root.removeRequested(path)
                }
            }
        }
    }
}
