// Picture Quick Look. A plain window, like the video preview: no title,
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

    on_ImageUrlChanged: zoomFlick.zoom = 1

    Timer {
        id: spaceLive
        interval: Motion.extraLongMs
        onTriggered: win._spaceLive = true
    }

    onVisibleChanged: if (visible) { win._spaceLive = false; spaceLive.restart(); }
    Component.onCompleted: spaceLive.restart()

    Flickable {
        id: zoomFlick
        anchors.fill: parent
        clip: true
        property real zoom: 1
        readonly property real _maxZoom: 8
        contentWidth: shot.width
        contentHeight: shot.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: zoom > 1

        Image {
            id: shot
            width: Math.max(1, zoomFlick.width * zoomFlick.zoom)
            height: Math.max(1, zoomFlick.height * zoomFlick.zoom)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
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

        // Wayland delivers the wheel as a synthesized scroll. A handler
        // that only accepts a plain mouse never sees it.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => zoomFlick._scale(event)
        }

        function _scale(event) {
            const angle = event.angleDelta.y || 0;
            const pixel = event.pixelDelta.y || 0;
            const steps = angle !== 0 ? angle / 120 : pixel / 48;
            if (!steps)
                return;
            const prev = zoom;
            const next = Math.min(_maxZoom, Math.max(1, prev * Math.pow(1.25, steps)));
            if (Math.abs(next - prev) < 0.001)
                return;
            event.accepted = true;
            const rx = contentWidth > 0 ? (contentX + event.x) / contentWidth : 0.5;
            const ry = contentHeight > 0 ? (contentY + event.y) / contentHeight : 0.5;
            zoom = next;
            Qt.callLater(() => {
                contentX = Math.max(0, rx * contentWidth - event.x);
                contentY = Math.max(0, ry * contentHeight - event.y);
            });
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
