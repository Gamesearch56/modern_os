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
    property alias headerExtra: titleBar.headerExtra
    property int elevation: 3
    property real cardWidth: Tokens.spacing.xxl * 16
    property real cardHeight: Tokens.spacing.xxl * 14
    property bool hugContent: false
    property bool closeVisible: true
    property string actionKey: ""
    property string actionIcon: ""
    property real chromeOpacity: Chrome.washOpacity
    property real scrimOpacity: Tokens.overlay.scrim
    property color cardColor: Colors.color.surfaceContainer
    property bool chromeHover: true

    signal closed()
    signal actionClicked()

    default property alias body: contentSlot.data

    property bool _entered: false
    readonly property bool _shown: root.open && root._entered
    readonly property real _hugHeight: {
        void titleBar.implicitHeight;
        const kids = contentSlot.children;
        const body = kids.length > 0 ? kids[0].implicitHeight : 0;
        const head = Math.max(titleBar.implicitHeight, Tokens.spacing.xxl);
        return Tokens.spacing.md * 2
            + head
            + Tokens.spacing.md
            + Math.max(1, Tokens.stroke.hairline)
            + Tokens.spacing.md
            + body;
    }

    MFocusWalk {
        id: overlayWalk
        scope: contentSlot
    }

    function arrowMove(dx: int, dy: int): bool {
        overlayWalk.move(dx, dy);
        return true;
    }

    function _placeBody() {
        if (contentSlot.children.length !== 1)
            return;
        const c = contentSlot.children[0];
        c.anchors.left = contentSlot.left;
        c.anchors.right = contentSlot.right;
        c.anchors.top = contentSlot.top;
        c.anchors.bottom = root.hugContent ? undefined : contentSlot.bottom;
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
            overlayWalk.focusFirst(true);
        else if (event.key === Qt.Key_End)
            overlayWalk.focusLast(true);
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

    Item {
        id: cardHost
        width: Math.min(root.cardWidth, root.width - Tokens.spacing.xxl)
        height: Math.min(root.hugContent ? root._hugHeight : root.cardHeight,
            root.height - Tokens.spacing.xxl * 2)
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: titleBar.offsetX
        anchors.verticalCenterOffset: titleBar.offsetY
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown)
        transformOrigin: Item.Center

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

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.medium
            color: root.cardColor
            opacity: root.chromeOpacity
        }

        MCard {
            id: card
            anchors.fill: parent
            level: root.elevation
            color: "transparent"
            padding: Tokens.spacing.md
            borderWidth: root.chromeHover && cardHover.hovered ? Tokens.stroke.focus : Tokens.stroke.hairline
            borderColor: root.chromeHover && cardHover.hovered ? Colors.color.primary : Colors.color.outlineVariant

            HoverHandler {
                id: cardHover
                enabled: root.chromeHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
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

            MOverlayBar {
                id: titleBar
                Layout.fillWidth: true
                titleKey: root.titleKey
                titleValue: root.titleValue
                subtitleKey: root.subtitleKey
                actionKey: root.actionKey
                actionIcon: root.actionIcon
                closeVisible: root.closeVisible
                space: root
                onClosed: root.closed()
                onActionClicked: root.actionClicked()
            }

            MDivider {
                Layout.fillWidth: true
            }

            Item {
                id: contentSlot
                Layout.fillWidth: true
                Layout.fillHeight: !root.hugContent
                implicitHeight: {
                    const kids = contentSlot.children;
                    return kids.length > 0 ? kids[0].implicitHeight : 0;
                }

                onChildrenChanged: root._placeBody()
            }
        }
        }
    }
}
