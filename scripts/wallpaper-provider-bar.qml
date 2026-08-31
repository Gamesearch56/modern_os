// MD3 chrome for the standalone wallpaper-provider window.
// Cannot import shell Widgets — those pull Quickshell via MIcon/Colors.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var theme: ({})
    property string urlText: ""
    property bool canGoBack: false
    property string backLabel: ""
    property string closeLabel: ""

    signal backClicked()
    signal closeClicked()

    readonly property var color: root.theme.color || ({})
    readonly property var spacing: root.theme.spacing || ({})
    readonly property var radius: root.theme.radius || ({})
    readonly property var icon: root.theme.icon || ({})
    readonly property var stroke: root.theme.stroke || ({})
    readonly property var interaction: root.theme.interaction || ({})

    readonly property real pad: Number(root.spacing.sm ?? 8)
    readonly property real btn: Number(root.spacing.xxl ?? 32)
    readonly property real glyph: Number(root.icon.md ?? 24)
    readonly property real hairline: Number(root.stroke.hairline ?? 1)
    readonly property real round: Number(root.radius.full ?? 9999)
    readonly property real hover: Number(root.interaction.hover ?? 0.08)
    readonly property real press: Number(root.interaction.press ?? 0.12)

    color: String(root.color.surfaceContainer || "")
    implicitHeight: root.pad * 2 + root.btn + root.hairline

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.hairline
        color: String(root.color.outlineVariant || "")
    }

    RowLayout {
        anchors.fill: parent
        anchors.bottomMargin: root.hairline
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Number(root.spacing.xs ?? 4)

        IconBtn {
            iconName: "go-previous-symbolic"
            label: root.backLabel
            iconColor: String(root.color.onSurface || "")
            layerColor: String(root.color.primary || "")
            enabled: root.canGoBack
            onClicked: root.backClicked()
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.urlText
            color: String(root.color.onSurfaceVariant || "")
            font.pixelSize: Number(root.spacing.md ?? 12)
            verticalAlignment: Text.AlignVCenter
            Accessible.ignored: true
        }

        IconBtn {
            iconName: "window-close"
            label: root.closeLabel
            iconColor: String(root.color.error || "")
            layerColor: String(root.color.error || "")
            onClicked: root.closeClicked()
        }
    }

    component IconBtn: AbstractButton {
        id: btn

        property string iconName: ""
        property string label: ""
        property color iconColor
        property color layerColor

        implicitWidth: root.btn
        implicitHeight: root.btn
        opacity: btn.enabled ? 1 : 0.38
        display: AbstractButton.IconOnly
        icon.name: btn.iconName
        icon.width: root.glyph
        icon.height: root.glyph
        icon.color: btn.iconColor
        Accessible.name: btn.label
        Accessible.role: Accessible.Button
        hoverEnabled: true

        background: Rectangle {
            radius: root.round
            color: btn.layerColor
            opacity: {
                if (!btn.enabled)
                    return 0;
                if (btn.pressed)
                    return root.press;
                if (btn.hovered)
                    return root.hover;
                return 0;
            }
        }
    }
}
