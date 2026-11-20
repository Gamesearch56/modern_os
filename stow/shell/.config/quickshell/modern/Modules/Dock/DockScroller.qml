// Scrolls the pin row when it is longer than the screen edge.
import QtQuick
import "../../Commons"

Flickable {
    id: root

    property bool vertical: false
    property string screenName: ""

    signal pinFocused()

    // A clip buffer keeps previous glyphs when a pin moves, and this HDR
    // panel shows that as color. A side column still has to clip, or the
    // extra icons paint through the top and bottom gap.
    clip: root.vertical
    boundsBehavior: Flickable.StopAtBounds
    interactive: false
    onContentWidthChanged: Qt.callLater(root._snap)
    onContentHeightChanged: Qt.callLater(root._snap)
    contentWidth: root.vertical ? width : Math.max(width, row.implicitWidth)
    contentHeight: root.vertical ? Math.max(height, row.implicitHeight) : height

    property real _edgeX: 0
    property real _edgeY: 0
    property bool _edgeRun: false

    function _snap() {
        const spanX = Math.max(0, root.contentWidth - root.width);
        const spanY = Math.max(0, root.contentHeight - root.height);
        const x = Math.round(Math.max(0, Math.min(spanX, root.contentX)));
        const y = Math.round(Math.max(0, Math.min(spanY, root.contentY)));
        if (root.contentX !== x)
            root.contentX = x;
        if (root.contentY !== y)
            root.contentY = y;
    }

    function track(x: real, y: real) {
        root._edgeX = x;
        root._edgeY = y;
        root._edgeRun = true;
        root.nudge(x, y);
    }

    function scrollWheel(w) {
        const step = DockLayout.iconSize + DockLayout.gap;
        const ax = w.angleDelta.x;
        const ay = w.angleDelta.y;
        const dx = ax !== 0 || ay !== 0 ? ax / 120 * step : w.pixelDelta.x;
        const dy = ax !== 0 || ay !== 0 ? ay / 120 * step : w.pixelDelta.y;
        root.scrollBy(dx, dy);
    }

    function scrollBy(dx: real, dy: real) {
        const span = root.vertical
            ? root.contentHeight - root.height
            : root.contentWidth - root.width;
        if (span <= 0)
            return;
        const delta = root.vertical
            ? (Math.abs(dy) >= Math.abs(dx) ? dy : dx)
            : (Math.abs(dx) >= Math.abs(dy) ? dx : dy);
        if (root.vertical)
            root.contentY = Math.round(Math.max(0, Math.min(span, root.contentY - delta)));
        else
            root.contentX = Math.round(Math.max(0, Math.min(span, root.contentX - delta)));
    }

    function nudge(x: real, y: real) {
        const edge = Tokens.spacing.xxl;
        const step = Tokens.spacing.md;
        if (root.vertical) {
            if (y < edge)
                root.scrollBy(0, step);
            else if (y > root.height - edge)
                root.scrollBy(0, -step);
        } else if (x < edge)
            root.scrollBy(step, 0);
        else if (x > root.width - edge)
            root.scrollBy(-step, 0);
    }

    function mapPoint(item, x: real, y: real): point {
        return row.mapFromItem(item, x, y);
    }

    function trashContains(x: real, y: real): bool {
        return row.trashContains(x, y);
    }

    function indexAt(x: real, y: real): int {
        return row.indexAt(x, y);
    }

    DockRow {
        id: row
        width: implicitWidth
        height: implicitHeight
        // A half pixel here shifts every glyph onto two subpixels.
        x: root.vertical
            ? Math.round((root.width - width) / 2)
            : Math.round(Math.max(0, (root.width - width) / 2))
        y: root.vertical
            ? Math.round(Math.max(0, (root.height - height) / 2))
            : Math.round((root.height - height) / 2)
        vertical: root.vertical
        screenName: root.screenName
        onPinFocused: root.pinFocused()
    }

    // Holding the pointer at the end of a full column has to keep moving.
    // One nudge per move never reaches a trash that starts off screen.
    Timer {
        interval: Math.max(Motion.shortMs, 1)
        repeat: true
        running: root._edgeRun && Dock.dragActive && Dock.dragFromDock
        onTriggered: root.nudge(root._edgeX, root._edgeY)
    }

    // Pins sit on top of this handler. A vertical wheel still moves a
    // horizontal dock; the pin forwards the same event when it is the target.
    WheelHandler {
        onWheel: (event) => root.scrollWheel(event)
    }
}
