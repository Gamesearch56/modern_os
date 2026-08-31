// MD3 button. `kind` is filled | tonal | outlined | text | destructive.
// Tonal uses primaryContainer so it follows the wallpaper, not grey secondary.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string kind: "filled"
    property string key: ""
    property var params: ({})
    property string iconName: ""
    property bool enabled: true
    property bool fillWidth: false
    property bool highlighted: false
    property bool busy: false
    property bool iconAfter: false

    signal clicked()

    readonly property bool _hovered: ma.containsMouse && root.enabled && !root.busy
    readonly property bool _pressed: ma.pressed

    readonly property var _colors: {
        const hot = root._hovered || root._pressed;
        switch (root.kind) {
        case "tonal":
            return { bg: Chrome.tonal.bg, fg: Chrome.tonal.fg, border: "transparent" };
        case "outlined":
            return {
                bg: hot ? Colors.color.primaryContainer : "transparent",
                fg: hot ? Colors.color.onPrimaryContainer : Colors.color.primary,
                border: Colors.color.outline
            };
        case "text":
            return {
                bg: hot ? Colors.color.primaryContainer : "transparent",
                fg: hot ? Colors.color.onPrimaryContainer : Colors.color.primary,
                border: "transparent"
            };
        case "destructive":
            return hot
                ? { bg: Colors.color.errorContainer, fg: Colors.color.onErrorContainer, border: "transparent" }
                : { bg: Colors.color.error, fg: Colors.color.onError, border: "transparent" };
        default:
            return hot
                ? { bg: Colors.color.primaryContainer, fg: Colors.color.onPrimaryContainer, border: "transparent" }
                : { bg: Chrome.filled.bg, fg: Chrome.filled.fg, border: "transparent" };
        }
    }

    implicitWidth: Math.max(Tokens.spacing.xxl * 2, row.implicitWidth + Tokens.spacing.lg * 2)
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    Layout.fillWidth: root.fillWidth
    opacity: (root.enabled && !root.busy) ? 1 : 0.38
    activeFocusOnTab: root.enabled && !root.busy
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key, root.params) : ""
    Accessible.onPressAction: {
        if (root.enabled && !root.busy)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.enabled && !root.busy) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root._colors.bg
        border.color: root.highlighted ? Colors.color.primary : root._colors.border
        border.width: root.highlighted ? 2 : (root.kind === "outlined" ? 1 : 0)

        Behavior on color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: {
            if (root.kind === "destructive")
                return Colors.color.onError;
            if (root.kind === "filled")
                return Colors.color.onPrimary;
            return Colors.color.primary;
        }
        opacity: Chrome.stateLayer(root._hovered, root._pressed)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm
        layoutDirection: root.iconAfter ? Qt.RightToLeft : Qt.LeftToRight

        MIcon {
            visible: root.iconName.length > 0 || root.busy
            name: root.busy ? (root.iconName.length > 0 ? root.iconName : "view-refresh") : root.iconName
            size: Tokens.icon.sm
            color: root._colors.fg
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: Motion.extraLongMs
                loops: Animation.Infinite
            }
        }

        MText {
            key: root.key
            params: root.params
            styleName: "labelLarge"
            color: root._colors.fg
            LayoutMirroring.enabled: false
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled && !root.busy
        hoverEnabled: true
        cursorShape: (root.enabled && !root.busy) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
        onPressed: bg.scale = 0.97
        onReleased: bg.scale = 1
        onCanceled: bg.scale = 1
    }

    MFocusRing {
        radius: Tokens.radius.full
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.springSnappy.spring
            damping: Motion.springSnappy.damping
        }
    }
}
