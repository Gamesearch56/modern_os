import QtQuick
import QtQuick.Effects
import "../../../../Commons"
import "../../../../Widgets"

Item {
    id: root

    property url source: ""
    property int turn: 0
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    // File pixels. The preview is downscaled, so the crop is scaled back up.
    property int pixelW: 0
    property int pixelH: 0

    readonly property real side: Tokens.spacing.xxl * 8
    readonly property bool ready: pic.status === Image.Ready
    readonly property var fit: root._fit()

    signal moved()

    implicitWidth: root.side
    implicitHeight: root.side

    function reset() {
        root.turn = 0;
        root.zoom = 1;
        root.panX = 0;
        root.panY = 0;
    }

    function _fit() {
        void [pic.status, pic.implicitWidth, pic.implicitHeight, root.turn, root.zoom, root.panX, root.panY];
        const natW = pic.implicitWidth;
        const natH = pic.implicitHeight;
        const swap = root.turn % 2 !== 0;
        const rotW = swap ? natH : natW;
        const rotH = swap ? natW : natH;
        const cover = rotW > 0 && rotH > 0 ? Math.max(root.side / rotW, root.side / rotH) : 1;
        const scale = cover * Math.max(1, root.zoom);
        const dispW = rotW * scale;
        const dispH = rotH * scale;
        const maxX = Math.max(0, (dispW - root.side) / 2);
        const maxY = Math.max(0, (dispH - root.side) / 2);
        return {
            natW: natW, natH: natH, rotW: rotW, rotH: rotH, scale: scale,
            dispW: dispW, dispH: dispH,
            panX: Math.max(-maxX, Math.min(maxX, root.panX)),
            panY: Math.max(-maxY, Math.min(maxY, root.panY))
        };
    }

    // The square sent to the saver is the circle the user is looking at.
    function box(): string {
        const fit = root._fit();
        if (!root.ready || fit.rotW < 1 || fit.scale <= 0)
            return "";
        const left = root.side / 2 + fit.panX - fit.dispW / 2;
        const top = root.side / 2 + fit.panY - fit.dispH / 2;
        let sx = (0 - left) / fit.scale;
        let sy = (0 - top) / fit.scale;
        let sw = root.side / fit.scale;
        let sh = root.side / fit.scale;
        if (sx < 0) { sw += sx; sx = 0; }
        if (sy < 0) { sh += sy; sy = 0; }
        let x = Math.max(0, Math.floor(sx));
        let y = Math.max(0, Math.floor(sy));
        let w = Math.max(1, Math.round(sw));
        let h = Math.max(1, Math.round(sh));
        if (x + w > fit.rotW)
            w = Math.max(1, Math.floor(fit.rotW - x));
        if (y + h > fit.rotH)
            h = Math.max(1, Math.floor(fit.rotH - y));
        return root._fileBox(x, y, w, h, fit);
    }

    function _fileBox(x: int, y: int, w: int, h: int, fit: var): string {
        const swap = root.turn % 2 !== 0;
        const fileW = root.pixelW > 0 ? root.pixelW : fit.natW;
        const fileH = root.pixelH > 0 ? root.pixelH : fit.natH;
        const rotFileW = swap ? fileH : fileW;
        const rotFileH = swap ? fileW : fileH;
        const sx = fit.rotW > 0 ? rotFileW / fit.rotW : 1;
        const sy = fit.rotH > 0 ? rotFileH / fit.rotH : 1;
        let fx = Math.max(0, Math.floor(x * sx));
        let fy = Math.max(0, Math.floor(y * sy));
        let fw = Math.max(1, Math.round(w * sx));
        let fh = Math.max(1, Math.round(h * sy));
        if (fx + fw > rotFileW)
            fw = Math.max(1, Math.floor(rotFileW - fx));
        if (fy + fh > rotFileH)
            fh = Math.max(1, Math.floor(rotFileH - fy));
        return fw + "x" + fh + "+" + fx + "+" + fy;
    }

    Item {
        id: frame
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cropMask
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.color.surfaceContainer
        }

        Image {
            id: pic
            source: root.source
            asynchronous: true
            cache: false
            // A full-size texture is freed on the same thread that draws the shell.
            sourceSize.width: root.side * 2
            sourceSize.height: root.side * 2
            fillMode: Image.PreserveAspectFit
            rotation: root.turn * 90
            transformOrigin: Item.Center
            width: Math.max(1, root.fit.natW * root.fit.scale)
            height: Math.max(1, root.fit.natH * root.fit.scale)
            x: root.side / 2 + root.fit.panX - width / 2
            y: root.side / 2 + root.fit.panY - height / 2
        }
    }

    Item {
        id: cropMask
        visible: false
        anchors.fill: parent
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: "transparent"
        border.width: Tokens.stroke.hairline
        border.color: Colors.color.outline
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.ready
        cursorShape: Qt.SizeAllCursor
        property real fromX: 0
        property real fromY: 0
        property real startX: 0
        property real startY: 0
        onPressed: (mouse) => {
            fromX = mouse.x;
            fromY = mouse.y;
            startX = root.panX;
            startY = root.panY;
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return;
            root.panX = startX + mouse.x - fromX;
            root.panY = startY + mouse.y - fromY;
        }
    }
}
