// A press that stays still is a click. A small move becomes a drag so
// the same control can launch and be rearranged.
import QtQuick
import "../Commons"

MouseArea {
    id: root

    property bool canDrag: true
    property bool _drag: false
    property bool _moved: false
    property real _sx: 0
    property real _sy: 0

    signal tapped()
    signal dragBegan(real x, real y, real lx, real ly)
    signal dragMoved(real x, real y, real lx, real ly)
    signal dragDropped(real x, real y, real lx, real ly)
    signal dragCanceled()

    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor

    function _global(mx: real, my: real): point {
        return mapToGlobal(mx, my);
    }

    onPressed: (mouse) => {
        root._sx = mouse.x;
        root._sy = mouse.y;
        root._drag = false;
        root._moved = false;
    }

    onPositionChanged: (mouse) => {
        if (!pressed)
            return;
        const dx = mouse.x - root._sx;
        const dy = mouse.y - root._sy;
        const gate = Tokens.spacing.xs;
        if (dx * dx + dy * dy < gate * gate)
            return;
        // A control that cannot drag is still a click, even if the
        // pointer drifts. Marking it moved would swallow the release.
        if (!root.canDrag)
            return;
        root._moved = true;
        const g = root._global(mouse.x, mouse.y);
        if (!root._drag) {
            root._drag = true;
            root.dragBegan(g.x, g.y, mouse.x, mouse.y);
        }
        root.dragMoved(g.x, g.y, mouse.x, mouse.y);
    }

    onReleased: (mouse) => {
        const g = root._global(mouse.x, mouse.y);
        if (root._drag)
            root.dragDropped(g.x, g.y, mouse.x, mouse.y);
        else if (!root._moved)
            root.tapped();
        root._drag = false;
        root._moved = false;
    }

    onCanceled: {
        // A stolen press that never became a drag is still a click.
        // Otherwise the dock icon does not open.
        if (root._drag)
            root.dragCanceled();
        else if (!root._moved)
            root.tapped();
        root._drag = false;
        root._moved = false;
    }
}
