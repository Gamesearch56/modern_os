// Modal dialog: scrim + centered MCard. `titleKey` / `bodyKey` are
// I18n paths. Confirm/cancel buttons emit signals; the caller decides
// what they do (power-off confirm, user-delete confirm).
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

    MCard {
        id: card
        level: 0
        color: Colors.color.surface
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        width: Math.min(parent.width - Tokens.spacing.xxl, Tokens.spacing.xxl * 12)
        implicitHeight: dialogCol.implicitHeight + padding * 2
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
            width: parent.width
            spacing: Tokens.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.md

                MText {
                    key: root.titleKey
                    params: root.titleParams
                    value: root.titleValue
                    styleName: "headlineSmall"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                MIconButton {
                    visible: root.destructiveKey.length > 0
                    close: true
                    escapeClicks: false
                    iconName: "edit-delete-symbolic"
                    key: root.destructiveKey
                    size: Tokens.spacing.xl
                    iconSize: Tokens.icon.xs
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    onClicked: root.destructiveClicked()
                }
            }

            MText {
                key: root.bodyKey
                params: root.bodyParams
                styleName: "bodyMedium"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                id: extraCol
                Layout.fillWidth: true
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
            dialogWalk.focusFirst();
        else if (event.key === Qt.Key_End)
            dialogWalk.focusLast();
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
