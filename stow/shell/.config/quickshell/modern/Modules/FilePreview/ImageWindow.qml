// Picture Quick Look. A plain window, like VideoWindow: no title,
// name, or close button. Wheel zoom stays on the picture.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../Commons"
import "../../Services"

FloatingWindow {
    id: win

    readonly property string _imageUrl: FilePreview.imagePath.length > 0
        ? ("file://" + encodeURI(FilePreview.imagePath)) : ""

    function _screen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
    }

    function _fit() {
        const sw = shot.sourceSize.width;
        const sh = shot.sourceSize.height;
        const screen = win._screen();
        if (sw <= 0 || sh <= 0 || !screen)
            return;
        const fit = Tokens.window.quicklookFit;
        const scale = Math.min((screen.width * fit) / sw, (screen.height * fit) / sh);
        win.implicitWidth = Math.max(1, Math.round(sw * scale));
        win.implicitHeight = Math.max(1, Math.round(sh * scale));
    }

    title: "modern.quicklook"
    color: Colors.color.background
    implicitWidth: Tokens.window.overlayWidth
    implicitHeight: Tokens.window.overlayHeight
    screen: win._screen()
    // The opening Space can be delivered when this window first takes
    // focus, which on a slow machine is after a short timer would fire.
    property bool _spaceLive: false

    on_ImageUrlChanged: stage.reset()

    Timer {
        id: spaceLive
        interval: Motion.extraLongMs
        onTriggered: win._spaceLive = true
    }

    onVisibleChanged: if (visible) { win._spaceLive = false; spaceLive.restart(); }
    Component.onCompleted: spaceLive.restart()

    // The fitted picture stays one size. Zoom is a transform, the same
    // motion as the image viewer: resizing the image on every wheel
    // step is what made the preview stutter.
    Item {
        id: stage
        anchors.fill: parent
        clip: true
        property real zoom: 1
        property real panX: 0
        property real panY: 0
        readonly property real _maxZoom: 8

        function reset() {
            zoom = 1;
            panX = 0;
            panY = 0;
        }

        function _clamp(offset: real, z: real, view: real): real {
            const span = view * z;
            if (span <= view + 0.5)
                return (view - span) / 2;
            return Math.max(view - span, Math.min(0, offset));
        }

        function _settle() {
            panX = _clamp(panX, zoom, width);
            panY = _clamp(panY, zoom, height);
        }

        onWidthChanged: _settle()
        onHeightChanged: _settle()

        function _setZoom(next: real, px: real, py: real) {
            next = Math.min(_maxZoom, Math.max(1, next));
            if (!(zoom > 0) || Math.abs(next - zoom) < 0.001)
                return;
            panX = px - (px - panX) * next / zoom;
            panY = py - (py - panY) * next / zoom;
            zoom = next;
            _settle();
        }

        Item {
            width: stage.width
            height: stage.height
            x: stage.panX
            y: stage.panY
            scale: stage.zoom
            transformOrigin: Item.TopLeft

            Image {
                id: shot
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                source: win._imageUrl
                onStatusChanged: {
                    if (status === Image.Ready)
                        win._fit();
                    if (status !== Image.Error || !win._imageUrl.length)
                        return;
                    const url = win._imageUrl;
                    Qt.callLater(() => {
                        if (shot.status === Image.Error && String(shot.source) === url)
                            FilePreview.markImageFailed();
                    });
                }
            }
        }

        // Wayland delivers the wheel as a synthesized scroll. A handler
        // that only accepts a plain mouse never sees it. A mouse also
        // sends a few pixels with its angle; those are not a second zoom.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                const angle = event.angleDelta.y || 0;
                const steps = angle !== 0 ? angle / 120 : (event.pixelDelta.y || 0) / 48;
                if (!steps)
                    return;
                stage._setZoom(stage.zoom * Math.pow(1.25, steps), event.x, event.y);
                event.accepted = true;
            }
        }

        DragHandler {
            property point start
            target: null
            enabled: stage.zoom > 1
            cursorShape: Qt.ClosedHandCursor
            onActiveChanged: if (active) start = Qt.point(stage.panX, stage.panY)
            onActiveTranslationChanged: {
                if (!active)
                    return;
                stage.panX = start.x + activeTranslation.x;
                stage.panY = start.y + activeTranslation.y;
                stage._settle();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: FilePreview.hide()
    }
    Shortcut {
        sequence: "Space"
        enabled: win._spaceLive
        context: Qt.WindowShortcut
        onActivated: FilePreview.spaceHide()
    }
}
