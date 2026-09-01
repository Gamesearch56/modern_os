// Shared overlay chrome: scrim + elevated card with title, optional
// header actions, close X, divider, and a fill content slot. Modules
// still own PanelWindow / LazyLoader / IPC (layer rule).
import QtQuick
import QtQuick.Layouts
import "../Commons"

FocusScope {
    id: root

    property bool open: true
    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property alias headerExtra: extraRow.data
    property int elevation: 3
    property real cardWidth: Tokens.spacing.xxl * 16
    property real cardHeight: Tokens.spacing.xxl * 14
    property bool closeVisible: true
    property string actionKey: ""
    property string actionIcon: ""
    property real chromeOpacity: Config.design.transparency ?? 0.85
    property real scrimOpacity: Tokens.overlay.scrim
    property color cardColor: Colors.color.surfaceContainer
    property bool chromeHover: true

    signal closed()
    signal actionClicked()

    default property alias body: contentSlot.data

    property bool _entered: false
    readonly property bool _shown: root.open && root._entered

    MFocusWalk {
        id: overlayWalk
        scope: contentSlot
    }

    function arrowMove(dx: int, dy: int): bool {
        overlayWalk.move(dx, dy);
        return true;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down)
            root.arrowMove(0, 1);
        else if (event.key === Qt.Key_Up)
            root.arrowMove(0, -1);
        else if (event.key === Qt.Key_Right)
            root.arrowMove(1, 0);
        else if (event.key === Qt.Key_Left)
            root.arrowMove(-1, 0);
        else if (event.key === Qt.Key_Home)
            overlayWalk.focusFirst();
        else if (event.key === Qt.Key_End)
            overlayWalk.focusLast();
        else
            return;
        event.accepted = true;
    }

    onOpenChanged: {
        if (!root.open)
            return;
        root.forceActiveFocus();
        Qt.callLater(() => overlayWalk.focusFirst());
    }

    anchors.fill: parent

    Component.onCompleted: root._entered = true

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? root.scrimOpacity : 0

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
        color: root.cardColor
        width: Math.min(root.cardWidth, root.width - Tokens.spacing.xxl)
        height: Math.min(root.cardHeight, root.height - Tokens.spacing.xxl * 2)
        anchors.centerIn: parent
        padding: Tokens.spacing.md
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown) * root.chromeOpacity
        transformOrigin: Item.Center
        borderWidth: root.chromeHover && cardHover.hovered ? Tokens.stroke.focus : Tokens.stroke.hairline
        borderColor: root.chromeHover && cardHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

        HoverHandler {
            id: cardHover
            enabled: root.chromeHover
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MText {
                        key: root.titleKey
                        value: root.titleValue
                        styleName: "headlineSmall"
                        Layout.fillWidth: true
                    }
                    MText {
                        visible: root.subtitleKey.length > 0
                        key: root.subtitleKey
                        styleName: "bodyMedium"
                        color: Colors.color.onSurfaceVariant
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    id: extraRow
                    spacing: Tokens.spacing.xs
                    visible: children.length > 0
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
