import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"
import "viewops.js" as Ops

// The picture: scaled by the viewer's scaling mode until the user zooms,
// then held at that zoom. The wheel and a pinch zoom around the pointer,
// a drag pans, a double-click toggles between fitting and 100 %.
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

    function setScale(to: real, px: real, py: real) {
        const from = root.scale;
        const next = Ops.clampScale(to, root.baseScale);
        const x = Ops.anchored(flick.contentX, px, root.width, root.boxW, from, next);
        const y = Ops.anchored(flick.contentY, py, root.height, root.boxH, from, next);
        root.zoom = next;
        root.follow = false;
        flick.contentX = x;
        flick.contentY = y;
    }

    function zoomBy(steps: real, px: real, py: real) {
        root.setScale(Ops.zoomed(root.scale, steps, root.baseScale), px, py);
    }

    function zoomIn() { root.zoomBy(1, root.width / 2, root.height / 2); }
    function zoomOut() { root.zoomBy(-1, root.width / 2, root.height / 2); }
    function actual() { root.setScale(1, root.width / 2, root.height / 2); }

    function fit() {
        root.follow = true;
        flick.contentX = 0;
        flick.contentY = 0;
    }

    function pan(dx: real, dy: real) {
        flick.contentX = Ops.panned(flick.contentX, dx, root.width, flick.contentWidth);
        flick.contentY = Ops.panned(flick.contentY, dy, root.height, flick.contentHeight);
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
            Qt.callLater(() => {
                flick.contentX = Math.max(0, (flick.contentWidth - root.width) / 2);
                flick.contentY = Math.max(0, (flick.contentHeight - root.height) / 2);
            });
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, root.boxW * root.scale)
        contentHeight: Math.max(height, root.boxH * root.scale)
        interactive: contentWidth > width || contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true

        Item {
            width: flick.contentWidth
            height: flick.contentHeight

            Loader {
                id: pic
                anchors.centerIn: parent
                width: root.srcW * root.scale
                height: root.srcH * root.scale
                rotation: ViewerDoc.rotation
                active: ViewerDoc.path.length > 0
                sourceComponent: root.animated ? moving : still
            }
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

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const steps = Ops.notches(event.angleDelta.y, event.pixelDelta.y);
            if (steps)
                root.zoomBy(steps, event.x, event.y);
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real startScale: 1
        onActiveChanged: if (active) startScale = root.scale
        onActiveScaleChanged: if (active) root.setScale(startScale * activeScale, centroid.position.x, centroid.position.y)
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
