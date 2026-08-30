// Shared overlay chrome: scrim + elevated card with title, optional
// header actions, close X, divider, and a fill content slot. Modules
// still own PanelWindow / LazyLoader / IPC (layer rule).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property bool open: true
    property string titleKey: ""
    property string titleValue: ""
    property int elevation: 3
    property real cardWidth: Tokens.spacing.xxl * 16
    property real cardHeight: Tokens.spacing.xxl * 14
    property bool closeVisible: true
    property string actionKey: ""
    property string actionIcon: ""

    signal closed()
    signal actionClicked()

    default property alias body: contentSlot.data

    property bool _entered: false
    readonly property bool _shown: root.open && root._entered

    anchors.fill: parent

    Component.onCompleted: root._entered = true

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    MCard {
        id: card
        level: root.elevation
        width: Math.min(root.cardWidth, root.width - Tokens.spacing.xxl)
        height: Math.min(root.cardHeight, root.height - Tokens.spacing.xxl * 2)
        anchors.centerIn: parent
        padding: Tokens.spacing.md
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown) * (Config.design.transparency ?? 0.85)
        transformOrigin: Item.Center
        borderWidth: cardHover.hovered ? 2 : 1
        borderColor: cardHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

        HoverHandler {
            id: cardHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on borderColor {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.sm

                MText {
                    key: root.titleKey
                    value: root.titleValue
                    styleName: "headlineSmall"
                    Layout.fillWidth: true
                }

                MButton {
                    visible: root.actionKey.length > 0
                    kind: "text"
                    key: root.actionKey
                    iconName: root.actionIcon
                    onClicked: root.actionClicked()
                }

                MIconButton {
                    visible: root.closeVisible
                    close: true
                    iconName: "window-close"
                    key: "bar.close"
                    onClicked: root.closed()
                }
            }

            MDivider {
                Layout.fillWidth: true
            }

            Item {
                id: contentSlot
                Layout.fillWidth: true
                Layout.fillHeight: true

                onChildrenChanged: {
                    if (children.length === 1)
                        children[0].anchors.fill = contentSlot;
                }
            }
        }
    }
}
