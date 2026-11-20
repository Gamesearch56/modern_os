// Title-row drag. FloatingWindow uses the compositor move (same path
// as Super+mouse). Layer-shell cards accumulate an offset instead.
import QtQuick
import QtQuick.Window

Item {
    id: root

    property bool systemMove: true
    property Item space: null
    property real offsetX: 0
    property real offsetY: 0
    // A click still lands when this is set. The window moves only after
    // the pointer travels this far, so a path field can be dragged.
    property real threshold: 0
    property int cursor: Qt.OpenHandCursor

    signal clicked()

    // MouseArea.cursorShape does not win on this session. The handler does.
    HoverHandler {
        cursorShape: root.cursor
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    property real _lx: 0
    property real _ly: 0
    property bool _moved: false

    function _point(mouse: var): var {
        const host = root.space
        if (host)
            return root.mapToItem(host, mouse.x, mouse.y)
        return ({ x: mouse.x, y: mouse.y })
    }

    function _startMove(): bool {
        const w = Window.window
        if (!w || typeof w.startSystemMove !== "function")
            return false
        return !!w.startSystemMove()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: root.cursor
        onPressed: (mouse) => {
            root._moved = false
            const p = root._point(mouse)
            root._lx = p.x
            root._ly = p.y
            if (root.threshold > 0)
                return
            if (root.systemMove && root._startMove())
                return
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            const p = root._point(mouse)
            const dx = p.x - root._lx
            const dy = p.y - root._ly
            if (root.threshold > 0) {
                if (root._moved)
                    return
                if (dx * dx + dy * dy < root.threshold * root.threshold)
                    return
                root._moved = true
                if (root.systemMove && root._startMove())
                    return
            }
            if (root.systemMove)
                return
            root.offsetX += dx
            root.offsetY += dy
            root._lx = p.x
            root._ly = p.y
        }
        onReleased: {
            if (!root._moved && root.threshold > 0)
                root.clicked()
            root._moved = false
        }
    }
}
