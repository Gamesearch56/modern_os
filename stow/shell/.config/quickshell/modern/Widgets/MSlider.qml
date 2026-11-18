// MD3 slider. Thick track from Tokens.slider; optional value suffix.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property bool enabled: true
    property bool showValue: false
    property int decimals: 0
    property bool wheel: false
    property real wheelStep: 0
    property real wheelFineStep: 0
    property string suffix: ""
    property bool _dragging: false
    property bool _hold: false
    property real _live: 0

    signal moved(real value)
    signal committed(real value)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.slider.thumb + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Slider
    Accessible.description: root._format(root._shown) + root.suffix
    Accessible.onIncreaseAction: root._emit(Math.min(root.to, root._shown + root._span / 20), true)
    Accessible.onDecreaseAction: root._emit(Math.max(root.from, root._shown - root._span / 20), true)

    Keys.onPressed: (event) => {
        const step = root._span / 20;
        if (event.key === Qt.Key_Left) {
            root._emit(Math.max(root.from, root._shown - step), true);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root._emit(Math.min(root.to, root._shown + step), true);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root._emit(root.from, true);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root._emit(root.to, true);
            event.accepted = true;
        }
    }

    readonly property real _span: Math.max(0.0001, root.to - root.from)
    readonly property real _shown: (root._dragging || root._hold) ? root._live : root.value
    readonly property real _ratio: Math.max(0, Math.min(1, (root._shown - root.from) / root._span))

    onValueChanged: {
        if (root._dragging)
            return;
        root._live = root.value;
        root._hold = false;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: Tokens.slider.trackHeight
                radius: Tokens.radius.full
                color: Colors.color.primaryContainer
            }

            Rectangle {
                anchors.verticalCenter: track.verticalCenter
                anchors.left: track.left
                width: track.width * root._ratio
                height: track.height
                radius: track.radius
                color: Colors.color.primary
            }

            Rectangle {
                id: thumb
                width: Tokens.slider.thumb
                height: Tokens.slider.thumb
                radius: Tokens.radius.full
                color: Colors.color.primary
                border.width: Tokens.stroke.hairline
                border.color: Colors.color.onPrimary
                anchors.verticalCenter: track.verticalCenter
                x: (track.width - width) * root._ratio
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: root.enabled
                preventStealing: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: (mouse) => {
                    ring.markPointer();
                    root.forceActiveFocus();
                    root._dragging = true;
                    root._lockFlick(true);
                    root._setFromX(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        root._setFromX(mouse.x);
                }
                onReleased: {
                    root._dragging = false;
                    root._lockFlick(false);
                    root._commitIfChanged();
                }
                onCanceled: {
                    root._dragging = false;
                    root._lockFlick(false);
                    root._commitIfChanged();
                }
            }

            WheelHandler {
                enabled: root.enabled && root.wheel
                onWheel: (w) => {
                    const fine = !!(w.modifiers & Qt.ShiftModifier);
                    const step = fine
                        ? (root.wheelFineStep > 0 ? root.wheelFineStep : Math.max(1, root._span / 100))
                        : (root.wheelStep > 0 ? root.wheelStep : Math.max(1, root._span / 20));
                    const next = Math.max(root.from, Math.min(root.to,
                        root._shown + (w.angleDelta.y > 0 ? step : -step)));
                    root._emit(next, true);
                    w.accepted = true;
                }
            }
        }

        MText {
            visible: root.showValue
            value: root._format(root._shown) + root.suffix
            styleName: "labelMedium"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: root.decimals > 0
                ? Tokens.spacing.xxl + Tokens.spacing.lg
                : Tokens.spacing.xxl + Tokens.spacing.sm
        }
    }

    function _lockFlick(lock: bool) {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined) {
                p.interactive = !lock;
                return;
            }
            p = p.parent;
        }
    }

    function _format(n: real): string {
        const d = Math.max(0, root.decimals);
        const f = Math.pow(10, d);
        const r = Math.round(Number(n) * f) / f;
        return d === 0 ? String(Math.round(r)) : r.toFixed(d);
    }

    function _emit(v: real, commit: bool) {
        root._live = v;
        root._hold = true;
        root.moved(v);
        if (commit)
            root.committed(v);
    }

    function _commitIfChanged() {
        if (Math.abs(root._live - root.value) <= root._span / 1000)
            return;
        root.committed(root._live);
    }

    MFocusRing {
        id: ring
        radius: Tokens.radius.full
    }

    function _setFromX(px: real) {
        const r = Math.max(0, Math.min(1, px / Math.max(1, width - (root.showValue ? Tokens.spacing.xxl : 0))));
        root._emit(root.from + r * root._span, false);
    }
}
