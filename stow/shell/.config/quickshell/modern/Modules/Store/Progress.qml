// Blocking install/remove log. Stays up on failure so pacman output
// is readable; success clears Store.mutating and the overlay closes.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool open: Store.mutating.length > 0 || Store.errorKey.length > 0
    readonly property bool failed: Store.mutating.length === 0 && Store.errorKey.length > 0
    readonly property string action: Store.mutating.length > 0 ? Store.mutAction : ""

    visible: root.open || scrim.opacity > 0
    enabled: root.open
    z: 110

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
            enabled: root.failed
            onClicked: Store.dismissError()
        }
    }

    MCard {
        level: 0
        color: Colors.color.surface
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        width: Math.min(parent.width - Tokens.spacing.xxl, Tokens.spacing.xxl * 14)
        implicitHeight: col.implicitHeight + padding * 2
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
            id: col
            width: parent.width
            spacing: Tokens.spacing.md

            MText {
                key: root.failed
                    ? (Store.errorKey.length > 0 ? Store.errorKey : "store.failed")
                    : (root.action === "remove" ? "store.removing"
                        : (root.action === "update" ? "store.updating" : "store.installing"))
                params: ({ name: Store.mutating.length > 0 ? Store.mutating : Store.lastName })
                styleName: "headlineSmall"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            MLinearProgress {
                visible: !root.failed
                Layout.fillWidth: true
                indeterminate: true
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.spacing.xxl * 8
                clip: true
                contentWidth: width
                contentHeight: logText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: {
                    if (contentHeight > height)
                        contentY = contentHeight - height;
                }

                TextEdit {
                    id: logText
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    selectByKeyboard: true
                    persistentSelection: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.PlainText
                    text: Store.log.trim().length > 0 ? Store.log.trim() : I18n.t("store.installLog")
                    color: root.failed ? Colors.color.error : Colors.color.onSurfaceVariant
                    selectionColor: Colors.color.primary
                    selectedTextColor: Colors.color.onPrimary
                    font.family: Typography.family.monospace
                    font.pixelSize: Typography.style("bodySmall").pixelSize
                    font.weight: Typography.style("bodySmall").weight
                    font.letterSpacing: Typography.style("bodySmall").letterSpacing
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: TextEdit.QtRendering
                    cursorVisible: false
                }
            }

            RowLayout {
                visible: root.failed || Store.authWait || Store.log.trim().length > 0
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.sm

                MButton {
                    visible: Store.authWait
                    kind: "outlined"
                    key: "store.cancel"
                    onClicked: Store.cancel()
                }

                MButton {
                    visible: Store.log.trim().length > 0
                    kind: "outlined"
                    key: "store.copyLog"
                    onClicked: {
                        Quickshell.clipboardText = Store.log.trim();
                        Store.notify(I18n.t("store.logCopied"), "");
                    }
                }

                MButton {
                    visible: root.failed
                    kind: "filled"
                    key: "bar.close"
                    onClicked: Store.dismissError()
                }
            }
        }
    }
}
