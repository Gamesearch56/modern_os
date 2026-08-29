// Line-art robot (antenna, round head, eyes, torso). Drawn in-scene so
// bar Loaders cannot miss a sibling SVG the way Qt.resolvedUrl did.
import QtQuick
import "../Commons"

Item {
    id: root

    property int size: Tokens.icon.md
    property color color: Colors.color.onSurface

    implicitWidth: root.size
    implicitHeight: root.size

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const w = canvas.width;
            const h = canvas.height;
            ctx.clearRect(0, 0, w, h);
            const inset = w * 0.1;
            const inner = Math.max(1, w - inset * 2);
            const u = inner / Tokens.icon.md;
            const ox = inset;
            const oy = inset;
            ctx.strokeStyle = root.color;
            ctx.fillStyle = "transparent";
            ctx.lineWidth = Math.max(Tokens.stroke.hairline, Tokens.stroke.focus * 0.85);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            ctx.beginPath();
            ctx.arc(ox + 12 * u, oy + 2.4 * u, 1.15 * u, 0, Math.PI * 2);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(ox + 12 * u, oy + 3.55 * u);
            ctx.lineTo(ox + 12 * u, oy + 6.1 * u);
            ctx.stroke();

            root._roundRect(ctx, ox + 5.4 * u, oy + 6.1 * u, 13.2 * u, 9.4 * u, 2.4 * u);
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(ox + 9.15 * u, oy + 10.35 * u, 1.55 * u, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(ox + 14.85 * u, oy + 10.35 * u, 1.55 * u, 0, Math.PI * 2);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(ox + 9.6 * u, oy + 13.55 * u);
            ctx.lineTo(ox + 14.4 * u, oy + 13.55 * u);
            ctx.stroke();

            root._roundRect(ctx, ox + 7.1 * u, oy + 16.4 * u, 9.8 * u, 5.7 * u, 1.6 * u);
            ctx.stroke();
        }
    }

    function _roundRect(ctx, x, y, w, h, r) {
        const rr = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + rr, y);
        ctx.arcTo(x + w, y, x + w, y + h, rr);
        ctx.arcTo(x + w, y + h, x, y + h, rr);
        ctx.arcTo(x, y + h, x, y, rr);
        ctx.arcTo(x, y, x + w, y, rr);
        ctx.closePath();
    }

    onColorChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
