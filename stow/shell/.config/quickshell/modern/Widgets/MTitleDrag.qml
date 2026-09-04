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

    property real _lx: 0
    property real _ly: 0

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
        cursorShape: Qt.OpenHandCursor
        onPressed: (mouse) => {
            if (root.systemMove && root._startMove())
                return
            const p = root._point(mouse)
            root._lx = p.x
            root._ly = p.y
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            if (root.systemMove)
                return
            const p = root._point(mouse)
            root.offsetX += p.x - root._lx
            root.offsetY += p.y - root._ly
            root._lx = p.x
            root._ly = p.y
        }
    }
}
