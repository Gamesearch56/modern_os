// Monitor cards in desk order. Drag a card left or right of another to
// rearrange the layout; a click without movement selects it.
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    property string selectedDesc: ""
    property int _dragFrom: -1
    property int _dropAt: -1

    signal picked(string desc)

    readonly property var mons: {
        void Hypr.monitors;
        void Hypr.monitorGen;
        return Hypr.orderedMonitors();
    }
    readonly property bool _dropShown: root._dragFrom >= 0 && root._dropAt >= 0
        && root._dropAt !== root._dragFrom && root._dropAt !== root._dragFrom + 1
    // The card the dragged display would land beside.
    readonly property int _dropTarget: !root._dropShown ? -1
        : (root._dropAt < root._dragFrom ? root._dropAt : root._dropAt - 1)

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight

    function _slotAt(px: real): int {
        let n = 0;
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && px > s.x + s.width / 2)
                n = i + 1;
        }
        return n;
    }

    function _markX(): real {
        const gap = row.spacing / 2;
        if (root._dropAt <= 0) {
            const first = rep.itemAt(0);
            return first ? first.x - gap : 0;
        }
        const prev = rep.itemAt(root._dropAt - 1);
        return prev ? prev.x + prev.width + gap : 0;
    }

    // Lays the displays out edge to edge in the new order; each keeps its
    // own vertical offset so a raised/lowered panel stays where it was.
    function move(from: int, to: int) {
        const list = root.mons.slice();
        if (from < 0 || from >= list.length)
            return;
        const at = to > from ? to - 1 : to;
        if (at === from || at < 0 || at >= list.length)
            return;
        const m = list.splice(from, 1)[0];
        list.splice(at, 0, m);
        const patches = {};
        let x = 0;
        for (let i = 0; i < list.length; i++) {
            const d = String(list[i].description || "");
            if (d.length)
                patches[d] = { position: x + "x" + Number(list[i].y || 0) };
            x += Hypr.logicalWidth(list[i]);
        }
        ConfigWrite.patchMonitors(patches);
        settle.restart();
    }

    Timer {
        id: settle
        interval: Math.max(Motion.extraLongMs, 1)
        onTriggered: Hypr.refreshMonitorDump()
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.md

        Repeater {
            id: rep
            model: root.mons
            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property string desc: String(modelData.description || "")
                property bool _moved: false
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: card.implicitHeight
                z: dragArea.drag.active ? 20 : 0

                MonitorCard {
                    id: card
                    width: slot.width
                    height: slot.height
                    monitor: slot.modelData
                    active: slot.desc.length > 0 && slot.desc === root.selectedDesc
                    dragging: dragArea.drag.active
                    dropTarget: root._dropTarget === slot.index
                    dropping: root._dropShown
                    onActivated: if (slot.desc.length) root.picked(slot.desc)
                    onNudged: (step) => root.move(slot.index, step < 0 ? slot.index - 1 : slot.index + 2)
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    drag.target: root.mons.length > 1 ? card : null
                    drag.axis: Drag.XAxis
                    onPressed: {
                        slot._moved = false;
                        root._dragFrom = slot.index;
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed)
                            return;
                        if (Math.abs(card.x) > Tokens.spacing.xs)
                            slot._moved = true;
                        if (slot._moved)
                            root._dropAt = root._slotAt(slot.mapToItem(row, mouse.x, mouse.y).x);
                    }
                    onReleased: {
                        if (slot._moved && root._dropShown)
                            root.move(root._dragFrom, root._dropAt);
                        else if (!slot._moved && slot.desc.length)
                            root.picked(slot.desc);
                        card.x = 0;
                        root._dragFrom = -1;
                        root._dropAt = -1;
                    }
                    onCanceled: {
                        card.x = 0;
                        root._dragFrom = -1;
                        root._dropAt = -1;
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root._dropShown
        x: root._markX() - width / 2
        width: Tokens.spacing.xs
        height: row.height
        radius: width / 2
        color: Colors.color.primary
    }
}
