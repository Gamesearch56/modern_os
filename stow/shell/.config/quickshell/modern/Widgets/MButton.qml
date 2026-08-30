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

    signal clicked()

    readonly property var _colors: {
        switch (root.kind) {
        case "tonal":
            return { bg: Chrome.tonal.bg, fg: Chrome.tonal.fg, border: "transparent" };
        case "outlined":
            return { bg: "transparent", fg: Colors.color.primary, border: Colors.color.outline };
        case "text":
            return { bg: "transparent", fg: Colors.color.primary, border: "transparent" };
        case "destructive":
            return { bg: Colors.color.error, fg: Colors.color.onError, border: "transparent" };
        default:
            return { bg: Chrome.filled.bg, fg: Chrome.filled.fg, border: "transparent" };
        }
    }

    implicitWidth: Math.max(Tokens.spacing.xxl * 2, row.implicitWidth + Tokens.spacing.lg * 2)
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    Layout.fillWidth: root.fillWidth
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key, root.params) : ""
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
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
        color: Colors.color.onSurface
        opacity: Chrome.stateLayer(hover.hovered, ma.pressed)
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm

        MIcon {
            visible: root.iconName.length > 0
            name: root.iconName
            size: Tokens.icon.sm
            color: root._colors.fg
        }

        MText {
            key: root.key
            params: root.params
            styleName: "labelLarge"
            color: root._colors.fg
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
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
