import QtQuick
import QtQuick.Layouts
import "../Commons"

// A media seek row: elapsed time, the slider, the length. Stateless:
// position and length in milliseconds in, seek(ms) out while dragging
// and on release. `progressKey` reads "{position} of {duration}".
// While the pointer is over the slider, `hovering`, `hoverMs` and `hoverX`
// (in this row's coordinates) say which spot it points at.
RowLayout {
    id: root

    property real position: 0
    property real length: 0
    property bool seekable: true
    property string nameKey: ""
    property string progressKey: ""

    readonly property bool hovering: slider.hovered
    readonly property real hoverX: slider.x + slider.hoverRatio * slider.width
    readonly property real hoverMs: slider.hoverRatio * root.length

    signal seek(real ms)

    spacing: Tokens.spacing.md

    // "1:05", "1:02:03": hours only when there are any.
    function clock(ms: real): string {
        const total = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const ss = s < 10 ? "0" + s : String(s);
        return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss;
    }

    MText {
        value: root.clock(slider._shown)
        styleName: "labelLarge"
        font.features: { "tnum": 1 }
    }

    MSlider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: Math.max(1, root.length)
        value: root.position
        enabled: root.seekable && root.length > 0
        Accessible.name: root.nameKey.length ? I18n.t(root.nameKey) : ""
        Accessible.description: root.progressKey.length
            ? I18n.t(root.progressKey, { position: root.clock(slider._shown), duration: root.clock(root.length) }) : ""
        onMoved: (v) => root.seek(v)
        onCommitted: (v) => root.seek(v)
    }

    MText {
        value: root.clock(root.length)
        styleName: "labelLarge"
        color: Colors.color.onSurfaceVariant
        font.features: { "tnum": 1 }
    }
}
