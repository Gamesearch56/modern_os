// MD3 button. `kind` is filled | tonal | outlined | text. Label comes
// from `key` (I18n) so a bare string never lands in a Text binding.
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

    signal clicked()

    readonly property var _colors: {
        switch (root.kind) {
        case "tonal":
            return { bg: Colors.color.secondaryContainer, fg: Colors.color.onSecondaryContainer, border: "transparent" };
        case "outlined":
            return { bg: "transparent", fg: Colors.color.primary, border: Colors.color.outline };
        case "text":
            return { bg: "transparent", fg: Colors.color.primary, border: "transparent" };
        case "destructive":
            return { bg: Colors.color.error, fg: Colors.color.onError, border: "transparent" };
        default:
            return { bg: Colors.color.primary, fg: Colors.color.onPrimary, border: "transparent" };
        }
    }

    implicitWidth: Math.max(Tokens.spacing.xxl * 2, row.implicitWidth + Tokens.spacing.lg * 2)
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    Layout.fillWidth: root.fillWidth
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root._colors.bg
        border.color: root._colors.border
        border.width: root.kind === "outlined" ? 1 : 0

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.sm

        MIcon {
            visible: root.iconName.length > 0
            name: root.iconName
            size: Tokens.spacing.lg
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
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressed: bg.scale = 0.97
        onReleased: bg.scale = 1
        onCanceled: bg.scale = 1
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.springSnappy.spring
            damping: Motion.springSnappy.damping
        }
    }
}
