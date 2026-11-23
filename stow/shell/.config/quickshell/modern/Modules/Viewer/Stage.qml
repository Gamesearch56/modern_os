import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"
import "viewops.js" as Ops

// The picture: scaled by the viewer's scaling mode until the user zooms,
// then held at that zoom. The wheel and a pinch zoom around the pointer
// (the point under the cursor stays put), a drag pans, and a
// double-click toggles between fitting and 100 %.
Item {
    id: root

    readonly property real srcW: pic.item ? pic.item.implicitWidth : 0
    readonly property real srcH: pic.item ? pic.item.implicitHeight : 0
    readonly property bool quarter: ViewerDoc.rotation % 180 !== 0
    readonly property real boxW: root.quarter ? root.srcH : root.srcW
    readonly property real boxH: root.quarter ? root.srcW : root.srcH
    readonly property real baseScale: Ops.baseScale(ViewerPrefs.scaling, Ops.fitScale(root.width, root.height, root.boxW, root.boxH))
    readonly property real scale: root.follow ? root.baseScale : root.zoom
    readonly property int percent: Math.round(root.scale * 100)
    readonly property bool ready: !!pic.item && pic.item.status === Image.Ready
    readonly property bool loading: !!pic.item && pic.item.status === Image.Loading
    readonly property bool animated: ViewerDoc.info.animated === true

    property bool follow: true
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    // 1 while the picture is fitted. Zooming changes only this transform,
    // the same way the video picture scales, instead of resizing a page.
    readonly property real factor: root.follow || !(root.baseScale > 0) ? 1 : root.zoom / root.baseScale
    readonly property bool canPan: root.boxW * root.baseScale * root.factor > root.width + 0.5
        || root.boxH * root.baseScale * root.factor > root.height + 0.5

    function _rect() {
        const w = root.boxW * root.baseScale;
        const h = root.boxH * root.baseScale;
        return { x: (root.width - w) / 2, y: (root.height - h) / 2, w: w, h: h };
    }

    function _settle() {
        if (root.follow)
            return;
        const r = root._rect();
        root.panX = Ops.clampOffset(root.panX, root.factor, root.width, r.x, r.x + r.w);
        root.panY = Ops.clampOffset(root.panY, root.factor, root.height, r.y, r.y + r.h);
    }

    function setScale(to: real, px: real, py: real) {
        const from = root.factor;
        const next = Ops.clampScale(to, root.baseScale);
        const nextFactor = root.baseScale > 0 ? next / root.baseScale : 1;
        if (!root.follow && next === root.zoom)
            return;
        root.panX = Ops.anchoredOffset(root.follow ? 0 : root.panX, px, from, nextFactor);
        root.panY = Ops.anchoredOffset(root.follow ? 0 : root.panY, py, from, nextFactor);
        root.zoom = next;
        root.follow = false;
        root._settle();
    }

    function zoomBy(steps: real, px: real, py: real) {
        root.setScale(Ops.zoomed(root.scale, steps, root.baseScale), px, py);
    }

    function zoomIn() { root.setScale(Ops.nudged(root.scale, 1, root.baseScale), root.width / 2, root.height / 2); }
    function zoomOut() { root.setScale(Ops.nudged(root.scale, -1, root.baseScale), root.width / 2, root.height / 2); }
    function actual() { root.setScale(1, root.width / 2, root.height / 2); }

    function fit() {
        root.follow = true;
        root.panX = 0;
        root.panY = 0;
    }

    function pan(dx: real, dy: real) {
        if (root.follow)
            return;
        root.panX -= dx;
        root.panY -= dy;
        root._settle();
    }

    clip: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Graphic
    Accessible.name: ViewerDoc.empty ? I18n.t("viewer.empty.title")
        : I18n.t("viewer.a11y.image", { name: ViewerDoc.name, index: ViewerDoc.index + 1, count: ViewerDoc.count })
    Accessible.description: root.ready ? I18n.t("viewer.a11y.size", { width: root.srcW, height: root.srcH, percent: root.percent }) : ""

    Connections {
        target: ViewerDoc
        function onShown() {
            root.fit();
        }
        // A turned picture swaps its width and height; the old scroll
        // offset would point at a different part of it.
        function onRotationChanged() {
            root._settle();
        }
    }

    onWidthChanged: root._settle()
    onHeightChanged: root._settle()

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const steps = Ops.notches(event.angleDelta.y, event.pixelDelta.y);
            if (!steps)
                return;
            root.zoomBy(steps, event.x, event.y);
            event.accepted = true;
        }
    }

    Item {
        width: root.width
        height: root.height
        x: root.follow ? 0 : root.panX
        y: root.follow ? 0 : root.panY
        scale: root.factor
        transformOrigin: Item.TopLeft

        Loader {
            id: pic
            anchors.centerIn: parent
            width: Math.max(1, root.srcW * root.baseScale)
            height: Math.max(1, root.srcH * root.baseScale)
            rotation: ViewerDoc.rotation
            active: ViewerDoc.path.length > 0
            sourceComponent: root.animated ? moving : still
        }
    }

    Component {
        id: still
        Image {
            source: Ops.fileUrl(ViewerDoc.path, ViewerDoc.revision)
            asynchronous: true
            cache: false
            autoTransform: true
            mipmap: true
            smooth: true
            onStatusChanged: ViewerDoc.failed = status === Image.Error
        }
    }

    Component {
        id: moving
        AnimatedImage {
            source: Ops.fileUrl(ViewerDoc.path, ViewerDoc.revision)
            asynchronous: true
            cache: false
            autoTransform: true
            smooth: true
            paused: ViewerDoc.paused
            onStatusChanged: ViewerDoc.failed = status === Image.Error
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real startScale: 1
        onActiveChanged: if (active) startScale = root.scale
        onActiveScaleChanged: if (active) root.setScale(startScale * activeScale, centroid.position.x, centroid.position.y)
    }

    DragHandler {
        property point start
        target: null
        enabled: root.canPan
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

    TapHandler {
        onDoubleTapped: (point) => {
            if (root.follow && Math.abs(root.baseScale - 1) > 0.01)
                root.setScale(1, point.position.x, point.position.y);
            else
                root.fit();
        }
    }

    MLinearProgress {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.loading
        indeterminate: true
    }

    MEmptyState {
        anchors.fill: parent
        visible: ViewerDoc.failed && !ViewerDoc.empty
        iconName: "image-missing"
        titleKey: "viewer.errors.cannotShow"
        hintKey: "viewer.errors.cannotShowHint"
    }
}
