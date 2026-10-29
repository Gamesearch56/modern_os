// Three side-by-side island columns. Drops are resolved by mapping
// the pointer onto a lane — Qt DropArea is unreliable across columns.
import QtQuick
import QtQuick.Layouts
import "../Commons"

ColumnLayout {
    id: root

    property var leftItems: []
    property var centerItems: []
    property var rightItems: []
    property var labelKey: function (id) { return String(id); }
    property var configurable: function (id) { return false; }
    property var iconName: function (id) { return ""; }
    property string leftTitleKey: ""
    property string centerTitleKey: ""
    property string rightTitleKey: ""
    property string emptyKey: "settings.bar.emptySlot"

    signal slotsChanged(var left, var center, var right)
    signal itemClicked(string id)

    property string _dragId: ""
    property string _dragSlot: ""
    property int _dragIndex: -1
    property string _hoverSlot: ""
    property int _hoverIndex: -1

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    function beginDrag(slot: string, index: int, id: string) {
        root._dragSlot = slot;
        root._dragIndex = index;
        root._dragId = id;
        root._lockFlick(true);
    }

    function dropOn(toSlot: string, toIndex: int) {
        const id = root._dragId;
        const fromSlot = root._dragSlot;
        const fromIndex = root._dragIndex;
        if (!id.length || fromIndex < 0 || toSlot.length === 0)
            return;
        const left = (root.leftItems || []).slice();
        const center = (root.centerItems || []).slice();
        const right = (root.rightItems || []).slice();
        const bag = (s) => s === "left" ? left : (s === "center" ? center : right);
        const src = bag(fromSlot);
        const dst = bag(toSlot);
        if (fromIndex >= src.length || src[fromIndex] !== id)
            return;
        src.splice(fromIndex, 1);
        let to = toIndex;
        if (to < 0)
            to = dst.length;
        if (fromSlot === toSlot && to > fromIndex)
            to -= 1;
        if (to < 0)
            to = 0;
        if (to > dst.length)
            to = dst.length;
        dst.splice(to, 0, id);
        root.slotsChanged(left, center, right);
    }

    function _hitLane(ma: var, mx: real, my: real): var {
        const cols = [
            { slot: "left", lane: leftLane },
            { slot: "center", lane: centerLane },
            { slot: "right", lane: rightLane }
        ];
        for (let i = 0; i < cols.length; i++) {
            const lane = cols[i].lane;
            const p = lane.listBox.mapFromItem(ma, mx, my);
            if (p.x >= 0 && p.x <= lane.listBox.width && p.y >= -Tokens.spacing.sm && p.y <= lane.listBox.height + Tokens.spacing.sm)
                return { slot: cols[i].slot, index: lane.indexAt(p.y) };
        }
        return null;
    }

    function hoverFrom(ma: var, mx: real, my: real): void {
        const hit = root._hitLane(ma, mx, my);
        if (!hit) {
            root._hoverSlot = "";
            root._hoverIndex = -1;
            return;
        }
        root._hoverSlot = hit.slot;
        root._hoverIndex = hit.index;
    }

    function dropFrom(ma: var, mx: real, my: real): void {
        const hit = root._hitLane(ma, mx, my);
        if (hit)
            root.dropOn(hit.slot, hit.index);
    }

    function endDrag() {
        root._dragId = "";
        root._dragSlot = "";
        root._dragIndex = -1;
        root._hoverSlot = "";
        root._hoverIndex = -1;
        root._lockFlick(false);
    }

    function _lockFlick(lock: bool) {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined) {
                p.interactive = !lock;
                return;
            }
            p = p.parent;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MSlotLane {
            id: leftLane
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            board: root
            slotId: "left"
            titleKey: root.leftTitleKey
            items: root.leftItems
            labelKey: root.labelKey
            iconName: root.iconName
            configurable: root.configurable
        }
        MSlotLane {
            id: centerLane
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            board: root
            slotId: "center"
            titleKey: root.centerTitleKey
            items: root.centerItems
            labelKey: root.labelKey
            iconName: root.iconName
            configurable: root.configurable
        }
        MSlotLane {
            id: rightLane
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            board: root
            slotId: "right"
            titleKey: root.rightTitleKey
            items: root.rightItems
            labelKey: root.labelKey
            iconName: root.iconName
            configurable: root.configurable
        }
    }
}
