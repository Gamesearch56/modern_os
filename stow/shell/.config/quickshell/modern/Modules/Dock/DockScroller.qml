// Scrolls the pin row when it is longer than the screen edge, and marks
// each end that has more pins past it (DockOverflow).
import QtQuick
import "../../Commons"
import "../../Services"

Item {
    id: root

    property bool vertical: false
    property string screenName: ""

    signal pinFocused()

    readonly property real span: Math.max(0, root.vertical
        ? flick.contentHeight - flick.height
        : flick.contentWidth - flick.width)
    readonly property real pos: root._pos
    readonly property bool dragging: Dock.dragActive && Dock.dragFromDock
    readonly property real _step: DockLayout.iconSize + DockLayout.gap
    readonly property real _edge: Tokens.spacing.xxl * 2

    // One scroll position along the dock; the view follows it on whole
    // pixels, since a half pixel shifts every glyph onto two subpixels.
    property real _pos: 0
    on_PosChanged: {
        const v = Math.round(root._pos);
        if (root.vertical)
            flick.contentY = v;
        else
            flick.contentX = v;
        root._stick = root.span > 0 && root._pos >= root.span - 1;
    }
    property real _pull: 0
    // At the end, a longer row (a pin added, the trash during a drag)
    // keeps the view at the end instead of leaving a hidden remainder.
    property bool _stick: false
    onSpanChanged: Qt.callLater(root._snap)

    function _clamp(v: real): real {
        return Math.max(0, Math.min(root.span, v));
    }

    function _jump(v: real) {
        glide.stop();
        root._pos = root._clamp(v);
    }

    function _glideTo(v: real) {
        const to = root._clamp(v);
        glide.stop();
        if (Math.abs(to - root._pos) < 1) {
            root._pos = to;
            return;
        }
        glide.from = root._pos;
        glide.to = to;
        glide.start();
    }

    function _snap() {
        if (root._stick && !glide.running)
            root._jump(root.span);
        else
            root._jump(glide.running ? glide.to : root._pos);
    }

    function track(x: real, y: real) {
        const along = root.vertical ? y : x;
        const size = root.vertical ? root.height : root.width;
        if (along < root._edge)
            root._pull = -Math.min(1, (root._edge - along) / root._edge);
        else if (along > size - root._edge)
            root._pull = Math.min(1, (along - size + root._edge) / root._edge);
        else
            root._pull = 0;
    }

    // A mouse wheel click is a whole 120-unit notch: it glides one pin,
    // and quick clicks add up instead of restarting. On Wayland a wheel
    // also reports a few pixels, so the notch wins; only a touchpad's
    // fractional scroll follows its pixels directly.
    function scrollWheel(w) {
        const angle = root._pick(w.angleDelta.x, w.angleDelta.y);
        const pixels = root._pick(w.pixelDelta.x, w.pixelDelta.y);
        if (pixels !== 0 && angle % 120 !== 0) {
            root._jump(root._pos - pixels);
            return;
        }
        if (angle !== 0)
            root._glideTo((glide.running ? glide.to : root._pos) - angle / 120 * root._step);
    }

    function scrollBy(dx: real, dy: real) {
        root._glideTo((glide.running ? glide.to : root._pos) - root._pick(dx, dy));
    }

    function _pick(dx: real, dy: real): real {
        return root.vertical
            ? (Math.abs(dy) >= Math.abs(dx) ? dy : dx)
            : (Math.abs(dx) >= Math.abs(dy) ? dx : dy);
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

    NumberAnimation {
        id: glide
        target: root
        property: "_pos"
        duration: Motion.mediumMs
        easing.type: Easing.OutCubic
    }

    // Holding a dragged pin at either end keeps scrolling, faster the
    // deeper it sits in the edge band: one pin per short beat at the edge.
    FrameAnimation {
        running: root.dragging && root._pull !== 0 && root.span > 0
        onTriggered: {
            const speed = root._step / Math.max(Motion.shortMs, 1) * 1000;
            root._jump(root._pos + root._pull * speed * frameTime);
        }
    }

    Connections {
        target: Dock
        function onDragActiveChanged() {
            if (!Dock.dragActive)
                root._pull = 0;
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        // A clip buffer keeps previous glyphs when a pin moves, and this
        // HDR panel shows that as color. A side column still has to clip,
        // or the extra icons paint through the top and bottom gap.
        clip: root.vertical
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        onContentWidthChanged: Qt.callLater(root._snap)
        onContentHeightChanged: Qt.callLater(root._snap)
        contentWidth: root.vertical ? width : Math.max(width, row.implicitWidth)
        contentHeight: root.vertical ? Math.max(height, row.implicitHeight) : height

        DockRow {
            id: row
            width: implicitWidth
            height: implicitHeight
            x: root.vertical
                ? Math.round((flick.width - width) / 2)
                : Math.round(Math.max(0, (flick.width - width) / 2))
            y: root.vertical
                ? Math.round(Math.max(0, (flick.height - height) / 2))
                : Math.round((flick.height - height) / 2)
            vertical: root.vertical
            screenName: root.screenName
            onPinFocused: root.pinFocused()
        }
    }

    DockOverflow {
        scroller: root
        atEnd: false
        vertical: root.vertical
        x: root.vertical ? Math.round((root.width - width) / 2) : 0
        y: root.vertical ? 0 : Math.round((root.height - height) / 2)
    }

    DockOverflow {
        scroller: root
        atEnd: true
        vertical: root.vertical
        x: root.vertical ? Math.round((root.width - width) / 2) : root.width - width
        y: root.vertical ? root.height - height : Math.round((root.height - height) / 2)
    }
}
