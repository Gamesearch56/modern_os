// Navigation puts the body back at the top before the new rows exist.
// A highlight chosen from outside the listing (a search result, a
// reveal) has to be brought into view once its row has a position.
import QtQuick
import "../../Commons"
import "../../Services"

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property Flickable flick: null
    property Repeater repeater: null
    property Item page: null
    property string mode: "list"
    property string pin: ""

    function queue() {
        const selected = Files.selected || [];
        root.pin = selected.length === 1 ? String(selected[0] || "") : "";
        if (!root.pin.length) {
            wait.stop();
            return;
        }
        wait.left = 4;
        Qt.callLater(root._afterLayout);
        wait.restart();
    }

    function _afterLayout() {
        if (root.apply())
            wait.stop();
    }

    function apply(): bool {
        if (!root.pin.length || !root._shown() || !root.repeater)
            return true;
        const index = root._index();
        if (index < 0)
            return false;
        const item = root.repeater.itemAt(index);
        if (!root._placed(index, item))
            return false;
        return root._reveal(item);
    }

    function _shown(): bool {
        if (root.page && !root.page.visible)
            return false;
        return root.flick && root.flick.height >= 1;
    }

    function _index(): int {
        const path = root.pin;
        const n = root.repeater.count;
        for (let i = 0; i < n; i++) {
            const item = root.repeater.itemAt(i);
            if (item && item.modelData && String(item.modelData.path || "") === path)
                return i;
        }
        return -1;
    }

    function _placed(index, item): bool {
        if (!item || item.height < 1)
            return false;
        if (item.y > 1 || index === 0)
            return true;
        if (root.mode !== "grid")
            return false;
        const cell = Tokens.window.filesCell;
        const gap = Tokens.spacing.sm;
        const cols = Math.max(1, Math.floor((root.flick.width + gap) / (cell + gap)));
        return index < cols;
    }

    function _reveal(item): bool {
        const flick = root.flick;
        const p = item.mapToItem(flick.contentItem, 0, 0);
        const pad = Tokens.spacing.sm;
        const top = p.y;
        const bottom = top + item.height;
        if (bottom > flick.contentHeight + 1)
            return false;
        const viewTop = flick.contentY;
        const viewBottom = viewTop + flick.height;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        let y = flick.contentY;
        if (top < viewTop + pad)
            y = top - pad;
        else if (bottom > viewBottom - pad)
            y = bottom - flick.height + pad;
        else
            return true;
        flick.contentY = Math.max(0, Math.min(maxY, y));
        return true;
    }

    Timer {
        id: wait
        interval: Motion.shortMs
        property int left: 0
        onTriggered: {
            if (root.apply() || left <= 0)
                return;
            left = left - 1;
            restart();
        }
    }

    Connections {
        target: Files
        function onSelectedChanged() { root.queue(); }
        function onListed() { root.queue(); }
    }

    Connections {
        target: root.page
        function onVisibleChanged() { root.queue(); }
    }

    Connections {
        target: root.flick
        function onContentHeightChanged() {
            if (root.pin.length)
                root.queue();
        }
    }
}
