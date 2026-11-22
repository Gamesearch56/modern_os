// Store as a Hyprland toplevel. Super+Q closes it as killactive.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Connections {
        target: Store
        function onNotify(summary, body) {
            Notifications.toast(summary, body || "");
        }
    }

    LazyLoader {
        active: Store.open

        FloatingWindow {
            id: win
            visible: Store.open
            title: "modern.store"
            color: "transparent"
            implicitWidth: Tokens.window.storeWidth
            implicitHeight: Tokens.window.storeHeight

            onVisibleChanged: {
                if (!visible) {
                    Store.hide();
                    return;
                }
                Qt.callLater(() => nav.focusSearch());
            }

            MWindowShell {
                id: card
                anchors.fill: parent
                titleKey: "store.title"
                iconName: "modern-store-symbolic"
                actionKey: Store.detailName.length ? "store.back" : ""
                actionIcon: Store.detailName.length ? "go-previous" : ""
                titleColumnWidth: Tokens.spacing.xxl * 9
                busy: Store.loading || Store.detailLoading || Store.mutating.length > 0
                onClosed: Store.hide()
                onActionClicked: Store.goBack()

                trailing: Item {
                    readonly property bool show: Passwd.canManage && Update.pending.length > 0
                    visible: show
                    implicitWidth: show ? updBtn.implicitWidth + Tokens.spacing.xs : 0
                    implicitHeight: show ? updBtn.implicitHeight : 0

                    MButton {
                        id: updBtn
                        kind: "tonal"
                        iconName: "system-software-update"
                        key: "store.updates"
                        onClicked: Settings.openAt("system", "")
                    }

                    MBadge {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: -Tokens.spacing.xs
                        count: Update.pending.length
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.lg

                    MPane {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true

                        Nav {
                            id: nav
                            anchors.fill: parent
                            tabTarget: content
                            onContentRequested: content.focusFirst()
                        }
                    }

                    Content {
                        id: content
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onNavRequested: nav.focusActive()
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (Store.previewShot.length > 0) {
                        Store.closePreview();
                        return;
                    }
                    if (Store.pendingName.length > 0) {
                        Store.cancel();
                        return;
                    }
                    if (Store.mutating.length > 0) {
                        Store.cancel();
                        return;
                    }
                    if (Store.errorKey.length > 0) {
                        Store.dismissError();
                        return;
                    }
                    if (Store.detailName.length > 0) {
                        Store.goBack();
                        return;
                    }
                    Store.hide();
                }
            }

            MDialog {
                id: ask
                parent: win.contentItem
                anchors.fill: parent
                // pendingAction is cleared to close this dialog, which
                // would otherwise fall through to the install label
                // while the card is still fading out.
                property string heldAction: ""
                property string heldName: ""
                readonly property string action: Store.pendingName.length > 0 && Store.pendingAction.length > 0
                    ? Store.pendingAction
                    : heldAction
                readonly property string pkgName: Store.pendingName.length > 0 ? Store.pendingName : heldName
                open: Store.pendingName.length > 0
                onOpenChanged: {
                    if (ask.open && Store.pendingAction.length > 0) {
                        ask.heldAction = Store.pendingAction;
                        ask.heldName = Store.pendingName;
                    }
                }
                titleKey: ask.action === "remove"
                    ? "store.confirmRemove"
                    : (ask.action === "update" ? "store.confirmUpdate" : "store.confirmInstall")
                titleParams: ({ name: ask.pkgName })
                bodyKey: ask.action === "remove"
                    ? "store.confirmRemoveBody"
                    : (ask.action === "update" ? "store.confirmUpdateBody" : "store.confirmInstallBody")
                bodyParams: ({ name: ask.pkgName })
                confirmKey: ask.action === "remove"
                    ? "store.remove"
                    : (ask.action === "update" ? "store.update" : "store.install")
                confirmEnabled: Store.mutating.length === 0
                destructive: ask.action === "remove"
                onConfirmed: Store.confirm()
                onCancelled: Store.cancel()
            }

            TapHandler {
                parent: win.contentItem
                acceptedButtons: Qt.BackButton
                onTapped: Store.goBack()
            }

            TapHandler {
                parent: win.contentItem
                acceptedButtons: Qt.ForwardButton
                onTapped: Store.goForward()
            }

            ShotPreview {
                parent: win.contentItem
                anchors.fill: parent
                z: 90
            }

            Progress {
                parent: win.contentItem
                anchors.fill: parent
            }
        }
    }
}
