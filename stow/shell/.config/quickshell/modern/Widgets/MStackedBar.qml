// Horizontal stacked bar. `segments` is [{ frac, color, id }]. Drawn on
// a Canvas so the pill clip is real — Item.clip is axis-aligned and
// would square off the ends over the track. Hover reports `id`.
import QtQuick
import "../Commons"

Item {
    id: root

    property var segments: []
    property string activeId: ""

    signal hovered(string id)

    implicitHeight: Tokens.spacing.lg
    implicitWidth: Tokens.spacing.xxl * 10

    readonly property color _track: Colors.color.surfaceContainerHighest
    readonly property color _stroke: Colors.color.outlineVariant

    onSegmentsChanged: canvas.requestPaint()
    onActiveIdChanged: canvas.requestPaint()
    on_TrackChanged: canvas.requestPaint()
    on_StrokeChanged: canvas.requestPaint()

    function _idAt(px: real): string {
        const segs = root.segments || [];
        const w = width;
        let x = 0;
        for (let i = 0; i < segs.length; i++) {
            const sw = w * Math.max(0, Number(segs[i].frac) || 0);
            if (px >= x && px < x + sw)
                return String(segs[i].id || "");
            x += sw;
        }
        return "";
    }

    function _pill(ctx, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(r, 0);
        ctx.lineTo(w - r, 0);
        ctx.quadraticCurveTo(w, 0, w, r);
        ctx.lineTo(w, h - r);
        ctx.quadraticCurveTo(w, h, w - r, h);
        ctx.lineTo(r, h);
        ctx.quadraticCurveTo(0, h, 0, h - r);
        ctx.lineTo(0, r);
        ctx.quadraticCurveTo(0, 0, r, 0);
        ctx.closePath();
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.reset();
            if (w <= 0 || h <= 0)
                return;
            const r = Math.min(h / 2, w / 2);
            root._pill(ctx, w, h, r);
            ctx.clip();
            ctx.fillStyle = String(root._track);
            ctx.fillRect(0, 0, w, h);
            const segs = root.segments || [];
            const hot = String(root.activeId || "");
            let x = 0;
            for (let i = 0; i < segs.length; i++) {
                const frac = Math.max(0, Math.min(1, Number(segs[i].frac) || 0));
                const sw = w * frac;
                const id = String(segs[i].id || "");
                ctx.globalAlpha = !hot || hot === id ? 1 : 0.38;
                ctx.fillStyle = String(segs[i].color || root._track);
                ctx.fillRect(x, 0, sw, h);
                x += sw;
            }
            ctx.globalAlpha = 1;
            root._pill(ctx, w, h, r);
            ctx.strokeStyle = String(root._stroke);
            ctx.lineWidth = Tokens.stroke.hairline;
            ctx.stroke();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: root.hovered(root._idAt(mouseX))
        onEntered: root.hovered(root._idAt(mouseX))
        onExited: root.hovered("")
    }
}
