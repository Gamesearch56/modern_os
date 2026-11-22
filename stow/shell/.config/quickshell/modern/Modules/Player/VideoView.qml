import QtQuick
import QtMultimedia
import "playops.js" as Ops

// The video picture, zoomable around a point: Ctrl+wheel (Playback) or a
// pinch scales it from fit up to Ops.maxZoom, a drag pans it while zoomed,
// and it never leaves a gap at an edge it could fill. Zooming back out to
// fit, or the next file, puts it back where it was.
Item {
    id: root

    readonly property alias output: video
    readonly property bool zoomed: root.zoom > 1
    readonly property real aspect: video.sourceRect.width > 0 ? video.sourceRect.height / video.sourceRect.width : 0
    property real zoom: 1
    property real panX: 0
    property real panY: 0

    function _settle() {
        const r = video.contentRect;
        root.panX = Ops.clampOffset(root.panX, root.zoom, root.width, r.x, r.x + r.width);
        root.panY = Ops.clampOffset(root.panY, root.zoom, root.height, r.y, r.y + r.height);
    }

    function setZoom(to: real, px: real, py: real) {
        const next = Ops.clampZoom(to);
        if (next === root.zoom)
            return;
        root.panX = Ops.anchoredOffset(root.panX, px, root.zoom, next);
        root.panY = Ops.anchoredOffset(root.panY, py, root.zoom, next);
        root.zoom = next;
        root._settle();
    }

    function zoomBy(steps: real, px: real, py: real) {
        root.setZoom(Ops.zoomed(root.zoom, steps), px, py);
    }

    function reset() {
        root.zoom = 1;
        root.panX = 0;
        root.panY = 0;
    }

    clip: true
    onWidthChanged: root._settle()
    onHeightChanged: root._settle()

    VideoOutput {
        id: video
        width: root.width
        height: root.height
        x: root.panX
        y: root.panY
        scale: root.zoom
        transformOrigin: Item.TopLeft
        fillMode: VideoOutput.PreserveAspectFit
        onContentRectChanged: root._settle()
    }

    PinchHandler {
        property real startZoom: 1
        target: null
        onActiveChanged: if (active) startZoom = root.zoom
        onActiveScaleChanged: if (active) root.setZoom(startZoom * activeScale, centroid.position.x, centroid.position.y)
    }

    DragHandler {
        property point start
        target: null
        enabled: root.zoomed
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: if (active) start = Qt.point(root.panX, root.panY)
        onActiveTranslationChanged: {
            if (!active)
                return;
            root.panX = start.x + activeTranslation.x;
            root.panY = start.y + activeTranslation.y;
            root._settle();
        }
    }
}
