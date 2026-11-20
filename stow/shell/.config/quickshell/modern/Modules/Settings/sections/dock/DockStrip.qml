// The settings pin field is a miniature of the dock: one centered row,
// the active theme, and the same icon size.
import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    property var board: null
    property var pins: []

    readonly property real _icon: DockLayout.iconSize
    readonly property bool _named: DockLayout.showNames
    readonly property real _nameH: _named ? Tokens.spacing.lg : 0
    readonly property real _cell: _icon + Tokens.spacing.sm
    readonly property string _edge: DockLayout.position

    // cross follows the on-screen edge, so a side dock would shrink this
    // horizontal preview. Size the pill from the row it actually draws.
    implicitHeight: Math.max(Tokens.spacing.xxl * 2, root._cell + root._nameH + DockLayout.pad * 2 + Tokens.spacing.sm)

    // The strip is a pill. Its caps slice an icon that sits on the end,
    // so the row scrolls inside the straight middle.
    readonly property real _inset: {
        const h = root.height > 0 ? root.height : root.implicitHeight;
        const r = Math.max(1, h / 2);
        const rowH = root._cell + root._nameH;
        const top = (h - rowH) / 2 + (root._named ? 0 : (root._cell - root._icon) / 2);
        const far = Math.min(r - 1, Math.max(Math.abs(top - r), Math.abs(top + root._icon - r)));
        return Math.ceil(r - Math.sqrt(r * r - far * far) + Tokens.spacing.sm);
    }

    function _pageFlick() {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined && p.contentHeight !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _verticalPixels(w) {
        if (w.pixelDelta && w.pixelDelta.y !== 0)
            return w.pixelDelta.y;
        return w.angleDelta.y / 8;
    }

    function _onWheel(w) {
        const mod = (w.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0;
        const px = w.pixelDelta ? w.pixelDelta.x : 0;
        const py = w.pixelDelta ? w.pixelDelta.y : 0;
        const horizontal = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) || Math.abs(px) > Math.abs(py);
        if (!mod && !horizontal) {
            root._nudgePage(root._verticalPixels(w));
            return;
        }
        const overflow = scroller.contentWidth - scroller.width;
        if (overflow <= 1)
            return;
        const pixels = (px !== 0 || py !== 0)
                ? (horizontal ? px : py)
                : (horizontal ? w.angleDelta.x : w.angleDelta.y) / 8;
        if (pixels === 0)
            return;
        scroller.cancelFlick();
        scroller.contentX = Math.max(0, Math.min(overflow, scroller.contentX - pixels));
    }

    function _nudgePage(pixels: real) {
        const flick = root._pageFlick();
        if (!flick || flick.interactive === false || pixels === 0)
            return;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        const next = Math.max(0, Math.min(maxY, flick.contentY - pixels));
        if (Math.abs(next - flick.contentY) < 0.5)
            return;
        if (flick.cancelFlick)
            flick.cancelFlick();
        flick.contentY = next;
    }

    function _reveal(x: real) {
        const maxX = Math.max(0, scroller.contentWidth - scroller.width);
        if (maxX <= 0)
            return;
        const edge = Tokens.spacing.xl;
        const step = Tokens.spacing.md;
        if (x < edge)
            scroller.contentX = Math.max(0, scroller.contentX - step);
        else if (x > root.width - edge)
            scroller.contentX = Math.min(maxX, scroller.contentX + step);
    }

    function indexAtGlobal(gx: real, gy: real): int {
        // Same space as the drag signal. mapFromGlobal is not its inverse
        // on a toplevel, so the window origin is subtracted instead.
        const origin = root.mapToGlobal(0, 0);
        const x = gx - origin.x;
        const y = gy - origin.y;
        const slop = Tokens.spacing.md;
        if (x < -slop || y < -slop || x > root.width + slop || y > root.height + slop)
            return -1;
        root._reveal(x);
        const n = pinsRep.count;
        if (n === 0)
            return 0;
        const rowOrigin = pinRow.mapToGlobal(0, 0);
        const local = Qt.point(gx - rowOrigin.x, gy - rowOrigin.y);
        for (let i = 0; i < n; i++) {
            const item = pinsRep.itemAt(i);
            if (item && local.x < item.x + item.width / 2)
                return i;
        }
        return n;
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surface
        opacity: Chrome.washOpacity
    }
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: "transparent"
        border.width: Tokens.stroke.hairline
        border.color: root.board && root.board._hover >= 0 ? Colors.color.primary : Colors.color.outlineVariant
    }

    MText {
        anchors.centerIn: parent
        visible: (root.pins || []).length === 0
        key: "settings.dock.empty"
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.leftMargin: root._inset
        anchors.rightMargin: root._inset
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        contentWidth: Math.max(width, pinRow.implicitWidth + Tokens.spacing.sm * 2)
        contentHeight: height

        // Shift or Ctrl plus the wheel moves the row. A plain vertical
        // notch keeps scrolling the page. A sideways wheel does too.
        WheelHandler {
            blocking: true
            onWheel: (w) => root._onWheel(w)
        }

        Row {
            id: pinRow
            spacing: DockLayout.gap
            width: implicitWidth
            height: root._cell + root._nameH
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(Tokens.spacing.sm, Math.round((scroller.width - width) / 2))

            Repeater {
                id: pinsRep
                model: (root.pins || []).length

                delegate: Item {
                    id: pin
                    required property int index
                    readonly property string appId: String((root.pins || [])[index] || "")
                    width: root._cell
                    height: root._cell + root._nameH
                    opacity: root.board && root.board._dragFrom === pin.index ? Tokens.interaction.cut : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: Dock.labelFor(pin.appId)

                    Rectangle {
                        visible: DockLayout.theme === "inventory"
                        anchors.horizontalCenter: iconBox.horizontalCenter
                        anchors.verticalCenter: iconBox.verticalCenter
                        width: root._icon + Tokens.spacing.xs
                        height: root._icon + Tokens.spacing.xs
                        radius: Tokens.radius.small
                        color: Colors.color.surfaceContainerHigh
                    }
                    Item {
                        id: iconBox
                        width: root._icon
                        height: root._icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root._named ? 0 : (root._cell - root._icon) / 2
                        MIcon {
                            anchors.centerIn: parent
                            name: Dock.iconFor(pin.appId)
                            size: root._icon
                            tint: false
                            preferSymbolic: false
                        }
                        Rectangle {
                            visible: DockLayout.theme === "beam"
                            z: 2
                            radius: Tokens.radius.full
                            color: Colors.color.primary
                            width: root._icon * 0.6
                            height: Tokens.stroke.focus * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root._edge === "top"
                                ? Tokens.spacing.xxs
                                : parent.height - height - Tokens.spacing.xxs
                        }
                    }
                    MText {
                        visible: root._named
                        anchors.top: iconBox.bottom
                        anchors.topMargin: Tokens.spacing.xs
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root._cell
                        horizontalAlignment: Text.AlignHCenter
                        value: Dock.labelFor(pin.appId)
                        styleName: "labelSmall"
                        color: Colors.color.onSurface
                        elide: Text.ElideRight
                    }
                    MIconButton {
                        id: removeButton
                        visible: pinHover.hovered
                        anchors.horizontalCenter: iconBox.right
                        anchors.verticalCenter: iconBox.top
                        z: 2
                        iconName: "edit-delete-symbolic"
                        key: "settings.dock.remove"
                        size: Tokens.spacing.lg + Tokens.spacing.xxs
                        iconSize: Tokens.spacing.md
                        glyphColor: Colors.color.onSurfaceVariant
                        onClicked: Dock.removeAt(pin.index)
                    }
                    HoverHandler { id: pinHover }
                    MDragArea {
                        id: pinDrag
                        anchors.fill: parent
                        z: 1
                        canDrag: pin.appId.length > 0
                        onWheel: (w) => root._onWheel(w)
                        onDragBegan: (x, y, lx, ly) => root.board.begin(pin.appId, pin.index, x, y, pinDrag, lx, ly)
                        onDragMoved: (x, y, lx, ly) => root.board.move(x, y, pinDrag, lx, ly)
                        onDragDropped: (x, y) => root.board.end(x, y)
                        onDragCanceled: root.board.cancel()
                    }
                }
            }
        }

        Rectangle {
            visible: root.board && root.board._dragId.length > 0 && root.board._hover >= 0
            width: Tokens.stroke.focus
            height: root._icon
            radius: Tokens.radius.full
            color: Colors.color.primary
            y: pinRow.y + (root._cell - root._icon) / 2
            x: {
                // The slot boundary is the icon edge. Sit in the middle
                // of the gap so the mark is not stuck to the next icon.
                const at = root.board ? root.board._hover : 0;
                const n = pinsRep.count;
                const half = pinRow.spacing / 2;
                if (n === 0)
                    return pinRow.x;
                if (at >= n) {
                    const last = pinsRep.itemAt(n - 1);
                    return last ? pinRow.x + last.x + last.width + half - width / 2 : pinRow.x;
                }
                const item = pinsRep.itemAt(Math.max(0, at));
                return item ? pinRow.x + item.x - half - width / 2 : pinRow.x;
            }
        }
    }
}
