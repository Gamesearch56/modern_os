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
                parent: win.contentItem
                anchors.fill: parent
                open: Store.pendingName.length > 0
                titleKey: Store.pendingAction === "remove"
                    ? "store.confirmRemove"
                    : (Store.pendingAction === "update" ? "store.confirmUpdate" : "store.confirmInstall")
                titleParams: ({ name: Store.pendingName })
                bodyKey: Store.pendingAction === "remove"
                    ? "store.confirmRemoveBody"
                    : (Store.pendingAction === "update" ? "store.confirmUpdateBody" : "store.confirmInstallBody")
                bodyParams: ({ name: Store.pendingName })
                confirmKey: Store.pendingAction === "remove"
                    ? "store.remove"
                    : (Store.pendingAction === "update" ? "store.update" : "store.install")
                confirmEnabled: Store.mutating.length === 0
                destructive: Store.pendingAction === "remove"
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
