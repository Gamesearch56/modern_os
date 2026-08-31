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
                titleColumnWidth: Tokens.spacing.xxl * 9
                busy: Store.loading || Store.mutating.length > 0
                subtitleKey: Store.mutating.length > 0 ? "store.working" : ""
                onClosed: Store.hide()

                trailing: Item {
                    implicitWidth: updBtn.implicitWidth
                    implicitHeight: updBtn.implicitHeight

                    MButton {
                        id: updBtn
                        kind: "tonal"
                        iconName: "system-software-update"
                        key: Update.pending.length > 0 ? "store.updates" : "store.updatesNone"
                        params: ({ n: String(Update.pending.length) })
                        onClicked: Settings.openAt("system", "")
                    }

                    MBadge {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: -Tokens.spacing.xs
                        anchors.rightMargin: -Tokens.spacing.xs
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
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Discover {
                            anchors.fill: parent
                            visible: Store.query.trim().length === 0 && Store.categoryId === "discover"
                        }

                        Results {
                            anchors.fill: parent
                            visible: Store.query.trim().length > 0 || Store.categoryId !== "discover"
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (Store.pendingName.length > 0) {
                        Store.cancel();
                        return;
                    }
                    Store.hide();
                }
            }

            MDialog {
                parent: win.contentItem
                anchors.fill: parent
                open: Store.pendingName.length > 0
                titleKey: Store.pendingAction === "remove" ? "store.confirmRemove" : "store.confirmInstall"
                titleParams: ({ name: Store.pendingName })
                confirmKey: Store.pendingAction === "remove" ? "store.remove" : "store.install"
                destructive: Store.pendingAction === "remove"
                onConfirmed: Store.confirm()
                onCancelled: Store.cancel()
            }
        }
    }
}
