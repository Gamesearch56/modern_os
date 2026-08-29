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
    property string suffix: ""

    signal moved(real value)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.slider.thumb + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Slider
    Accessible.description: String(Math.round(root.value))
    Accessible.onIncreaseAction: root.moved(Math.min(root.to, root.value + root._span / 20))
    Accessible.onDecreaseAction: root.moved(Math.max(root.from, root.value - root._span / 20))

    Keys.onPressed: (event) => {
        const step = root._span / 20;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.moved(Math.max(root.from, root.value - step));
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.moved(Math.min(root.to, root.value + step));
            event.accepted = true;
        }
    }

    readonly property real _span: Math.max(0.0001, root.to - root.from)
    readonly property real _ratio: Math.max(0, Math.min(1, (root.value - root.from) / root._span))

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
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: (mouse) => {
                    root.forceActiveFocus();
                    root._setFromX(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        root._setFromX(mouse.x);
                }
                onWheel: (w) => {
                    const step = root._span / 20;
                    const dy = w.angleDelta.y;
                    if (dy === 0)
                        return;
                    root.moved(Math.max(root.from, Math.min(root.to, root.value + (dy > 0 ? step : -step))));
                    w.accepted = true;
                }
            }
        }

        MText {
            visible: root.showValue
            value: Math.round(root.value) + root.suffix
            styleName: "labelMedium"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: Tokens.spacing.xxl + Tokens.spacing.sm
        }
    }

    MFocusRing {
        radius: Tokens.radius.full
    }

    function _setFromX(px: real) {
        const r = Math.max(0, Math.min(1, px / Math.max(1, width - (root.showValue ? Tokens.spacing.xxl : 0))));
        root.moved(root.from + r * root._span);
    }
}
