import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    readonly property int count: (root.windows || []).length
    readonly property int columns: {
        const n = root.count;
        if (n <= 1)
            return 1;
        if (n <= 4)
            return 2;
        if (n <= 9)
            return 3;
        return 4;
    }
    readonly property int rows: Math.max(1, Math.ceil(root.count / Math.max(1, root.columns)))
    readonly property real labelBlock: Tokens.overview.caption + Tokens.overview.labelGap
    readonly property real gridTop: Tokens.overview.inset

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

    opacity: Overview.progress

    function moveBy(delta: int) {
        const n = root.count;
        if (n <= 0)
            return;
        root.currentIndex = ((root.currentIndex + delta) % n + n) % n;
    }

    function activate() {
        const win = (root.windows || [])[root.currentIndex];
        const addr = win && win.address ? String(win.address) : "";
        if (!addr.length)
            return;
        Hypr.activateWindow(addr);
        Overview.dismiss();
    }

    function _selectFocused() {
        const list = root.windows || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].activated) {
                root.currentIndex = i;
                return;
            }
        }
        root.currentIndex = 0;
    }

    function slotFor(index: int): var {
        const cols = Math.max(1, root.columns);
        const rows = root.rows;
        const gap = Tokens.overview.gap;
        const inset = Tokens.overview.inset;
        const availW = Math.max(1, root.width - inset * 2);
        const availH = Math.max(1, root.height - inset * 2);
        const fitW = (availW - gap * Math.max(0, cols - 1)) / cols;
        const fitH = (availH - gap * Math.max(0, rows - 1)) / rows;
        const cellW = Math.min(Tokens.overview.maxWidth, fitW);
        const cellH = Math.min(Tokens.overview.maxHeight, fitH);
        const previewH = Math.max(Tokens.spacing.xxl, cellH - root.labelBlock);
        const contentW = cols * cellW + gap * Math.max(0, cols - 1);
        const contentH = rows * cellH + gap * Math.max(0, rows - 1);
        const originX = Math.max(inset, (root.width - contentW) / 2);
        const originY = Math.max(inset, (root.height - contentH) / 2);
        const col = index % cols;
        const row = Math.floor(index / cols);
        return {
            x: originX + col * (cellW + gap),
            y: originY + row * (cellH + gap),
            w: cellW,
            h: previewH
        };
    }

    function _wheel(event) {
        const ax = event.angleDelta.x;
        const ay = event.angleDelta.y;
        if (ax === 0 && ay === 0)
            return;
        const step = Math.abs(ax) > Math.abs(ay) ? ax : ay;
        root.moveBy(step > 0 ? -1 : 1);
    }

    onCountChanged: {
        if (root.currentIndex >= root.count)
            root.currentIndex = Math.max(0, root.count - 1);
    }
    Component.onCompleted: root._selectFocused()

    Rectangle {
        anchors.fill: parent
        color: Colors.color.surface
        opacity: Chrome.washOpacity

        MouseArea {
            anchors.fill: parent
            onClicked: Overview.dismiss()
        }
    }

    MEmptyState {
        visible: root.count === 0
        anchors.top: parent.top
        anchors.topMargin: root.gridTop
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        iconName: "view-pages-overview"
        titleKey: "overview.empty"
        hintKey: "overview.emptyHint"
    }

    Repeater {
        model: root.count

        Item {
            id: cell
            required property int index
            readonly property var win: (root.windows || [])[index]
            readonly property var slot: root.slotFor(index)
            readonly property bool selected: root.currentIndex === index

            x: slot.x
            y: slot.y
            width: Math.max(1, slot.w)
            height: Math.max(1, slot.h) + root.labelBlock
            z: selected ? 2 : 1

            WindowCard {
                anchors.fill: parent
                win: cell.win
                selected: cell.selected
                onHovered: root.currentIndex = index
                onClicked: {
                    root.currentIndex = index;
                    root.activate();
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => root._wheel(event)
    }
}
