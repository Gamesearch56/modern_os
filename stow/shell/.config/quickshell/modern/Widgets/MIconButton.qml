// Circular icon-only button. Hover fades a primary state-layer.
import QtQuick
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property url iconSource: ""
    property string key: ""
    property bool checked: false
    property bool enabled: true
    property int size: Tokens.spacing.xxl
    property int iconSize: Tokens.icon.md
    property bool close: false
    property bool tint: true
    property bool busy: false
    property bool tabFocus: true
    property bool pointer: true
    property bool acceptWheel: false
    property bool escapeClicks: root.close
    property bool highlighted: false
    property bool tip: false
    property color glyphColor: Colors.color.onSurface

    signal clicked()
    signal middleClicked()
    signal rightClicked()
    signal wheel(real steps, bool fine)

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.tabFocus && root.enabled && !root.busy
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key) : root.iconName
    Accessible.onPressAction: {
        if (root.enabled && !root.busy)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if (root.busy || !root.enabled)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onEscapePressed: (event) => {
        if (!root.escapeClicks || root.busy || !root.enabled)
            return;
        root.clicked();
        event.accepted = true;
    }

    property bool _hover: false
    property bool _suppressHover: false
    property bool _tipHold: false
    property bool _tipReady: false

    function _armTip() {
        const hot = tipHover.hovered && root.tip && root._tipHold && root.key.length > 0 && !ma.pressed;
        if (!hot) {
            tipDelay.stop();
            root._tipReady = false;
            return;
        }
        if (!tipDelay.running && !root._tipReady)
            tipDelay.restart();
    }

    readonly property color _iconColor: {
        if (root.close)
            return Colors.color.error;
        if (root.checked)
            return Colors.color.onPrimaryContainer;
        return root.glyphColor;
    }

    readonly property real _layer: Chrome.stateLayer(root._hover && !root.checked && !root.busy, ma.pressed && !root.checked && !root.busy)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Chrome.tonal.bg
        visible: root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.close ? Colors.color.error : Colors.color.primary
        visible: root._layer > 0
        opacity: root._layer
    }

    MIcon {
        id: glyph
        anchors.centerIn: parent
        name: root.iconName
        source: root.iconSource
        size: root.iconSize
        color: root._iconColor
        tint: root.tint
        RotationAnimation on rotation {
            running: root.busy
            from: 0
            to: 360
            duration: Motion.extraLongMs
            loops: Animation.Infinite
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: 1
        enabled: root.enabled && !root.busy
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: (root.enabled && !root.busy && root.pointer) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: {
            if (!root._suppressHover)
                root._hover = true;
        }
        onExited: {
            if (root.checked)
                return;
            root._hover = false;
            root._suppressHover = false;
        }
        onContainsMouseChanged: {
            if (containsMouse) {
                root._hover = true;
                return;
            }
            if (root.checked)
                return;
            root._hover = false;
            root._suppressHover = false;
        }
        onPressed: {
            ring.markPointer();
            root._tipHold = false;
            root._armTip();
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
            root._hover = true;
            root._suppressHover = false;
        }
        onWheel: (w) => {
            w.accepted = root.acceptWheel;
            root.wheel(w.angleDelta.y > 0 ? 1 : -1, !!(w.modifiers & Qt.ShiftModifier));
        }
    }

    HoverHandler {
        enabled: root.enabled && !root.busy && root.pointer
        cursorShape: Qt.PointingHandCursor
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    HoverHandler {
        id: tipHover
        enabled: root.tip && root.key.length > 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            if (hovered)
                root._tipHold = true;
            root._armTip();
        }
    }

    Timer {
        id: tipDelay
        interval: Motion.mediumMs
        onTriggered: root._tipReady = true
    }

    MTooltip {
        open: root._tipReady && tipHover.hovered && root._tipHold && !ma.pressed
        key: root.key
    }

    onBusyChanged: {
        if (!root.busy)
            glyph.rotation = 0;
    }

    onCheckedChanged: {
        if (root.checked) {
            root._hover = true;
            root._suppressHover = false;
            return;
        }
        root._hover = false;
        root._suppressHover = true;
    }

    MFocusRing {
        id: ring
        radius: Tokens.radius.full
        ringColor: root.close ? Colors.color.error : Colors.color.primary
        active: root.highlighted || (root.activeFocus && ring._shown && !ring._pointer)
    }
}
