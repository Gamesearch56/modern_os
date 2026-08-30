// Modal dialog: scrim + centered MCard. `titleKey` / `bodyKey` are
// I18n paths. Confirm/cancel buttons emit signals; the caller decides
// what they do (power-off confirm, user-delete confirm).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
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
        if (root.open)
            root.forceActiveFocus();
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

                MText {
                    visible: root.destructiveKey.length > 0
                    key: root.destructiveKey
                    styleName: "labelLarge"
                    color: Colors.color.error
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Accessible.role: Accessible.Button
                    Accessible.name: root.destructiveKey.length > 0 ? I18n.t(root.destructiveKey) : ""
                    Accessible.onPressAction: root.destructiveClicked()

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.destructiveClicked()
                    }
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
}
