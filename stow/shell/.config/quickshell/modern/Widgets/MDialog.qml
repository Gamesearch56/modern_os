// Modal dialog: scrim + centered glass card (Settings wash, hairline
// only — not a window chrome). `titleKey` / `bodyKey` are I18n paths.
import QtQuick
import QtQuick.Layouts
import "../Commons"

FocusScope {
    id: root

    property bool open: false
    property string titleKey: ""
    property var titleParams: ({})
    property string titleValue: ""
    property string bodyKey: ""
    property var bodyParams: ({})
    property string confirmKey: "powerMenu.confirmTitle"
    property string cancelKey: "powerMenu.cancel"
    property string destructiveKey: ""
    property bool destructive: false
    property bool confirmEnabled: true
    property bool wide: false
    default property alias extra: extraCol.data

    signal confirmed()
    signal cancelled()
    signal destructiveClicked()

    visible: root.open || scrim.opacity > 0
    z: 100
    activeFocusOnTab: root.open
    Accessible.role: Accessible.Dialog
    Accessible.name: root.titleKey.length > 0 ? I18n.t(root.titleKey, root.titleParams) : root.titleValue

    onOpenChanged: {
        if (!root.open)
            return;
        root.forceActiveFocus();
        Qt.callLater(() => {
            if (extraCol.children.length > 0)
                dialogWalk.focusFirst();
            else
                dialogWalk.focusLast();
        });
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root.open ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelled()
        }
    }

    MPanelSurface {
        id: card
        width: Math.min(parent.width - Tokens.spacing.xxl,
            root.wide ? Tokens.panel.dialogWide : Tokens.panel.dialogWidth)
        implicitHeight: dialogCol.implicitHeight + Tokens.spacing.lg * 2
        anchors.centerIn: parent
        scale: Motion.overlayScale(root.open)
        opacity: Motion.overlayOpacity(root.open)

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }

        ColumnLayout {
            id: dialogCol
            x: Tokens.spacing.lg
            y: Tokens.spacing.lg
            width: parent.width - Tokens.spacing.lg * 2
            spacing: Tokens.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.md

                MText {
                    key: root.titleKey
                    params: root.titleParams
                    value: root.titleValue
                    styleName: "headlineSmall"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                }

                MIconButton {
                    visible: root.destructiveKey.length > 0
                    close: true
                    escapeClicks: false
                    iconName: "edit-delete-symbolic"
                    key: root.destructiveKey
                    iconSize: Tokens.icon.xs
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    onClicked: root.destructiveClicked()
                }
            }

            MText {
                visible: root.bodyKey.length > 0
                key: root.bodyKey
                params: root.bodyParams
                styleName: "bodyMedium"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                id: extraCol
                visible: extraCol.children.length > 0
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.md
                spacing: Tokens.spacing.sm
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.sm

                MButton {
                    kind: "text"
                    key: root.cancelKey
                    onClicked: root.cancelled()
                }

                MButton {
                    kind: root.destructive ? "destructive" : "filled"
                    key: root.confirmKey
                    enabled: root.confirmEnabled
                    onClicked: root.confirmed()
                }
            }
        }
    }

    Keys.onEscapePressed: root.cancelled()
    Keys.onReturnPressed: {
        if (root.open && root.confirmEnabled)
            root.confirmed();
    }
    Keys.onEnterPressed: {
        if (root.open && root.confirmEnabled)
            root.confirmed();
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
            dialogWalk.focusFirst(true);
        else if (event.key === Qt.Key_End)
            dialogWalk.focusLast(true);
        else
            return;
        event.accepted = true;
    }

    MFocusWalk {
        id: dialogWalk
        scope: card
    }

    function arrowMove(dx: int, dy: int): bool {
        dialogWalk.move(dx, dy);
        return true;
    }
}
