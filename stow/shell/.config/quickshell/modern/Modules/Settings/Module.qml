// Settings as a Hyprland toplevel. Super+Q closes it as killactive.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Connections {
        target: Update
        function onNotify(summary, body) {
            Notifications.toast(summary, body || "");
        }
    }

    Connections {
        target: FilePick
        function onDirectoryPicked(path, key) {
            if (key === "screenshots.videoDirectory")
                ConfigWrite.set("screenshots.videoDirectory", path);
            else
                ConfigWrite.set("screenshots.directory", path);
        }
        function onPickFinished(section) {
            Settings.openAt(section || "screenshots", "");
        }
    }

    LazyLoader {
        active: Settings.open

        FloatingWindow {
            id: win
            visible: Settings.open
            title: "modern.settings"
            color: "transparent"
            implicitWidth: Tokens.window.settingsWidth
            implicitHeight: Tokens.window.settingsHeight

            Catalog { id: catalog }

            onVisibleChanged: {
                if (!visible) {
                    Settings.close();
                    return;
                }
                Qt.callLater(() => nav.focusSearch());
            }

            MWindowShell {
                id: card
                anchors.fill: parent
                titleKey: "settings.title"
                titleColumnWidth: Tokens.spacing.xxl * 9
                busy: ConfigWrite.pending || Theme.busy
                onClosed: Settings.close()

                RowLayout {
                    spacing: Tokens.spacing.lg

                    MPane {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true

                        Nav {
                            id: nav
                            anchors.fill: parent
                            catalog: catalog
                            tabTarget: contentScope
                            onContentRequested: contentScope.focusFirst()
                        }
                    }

                    FocusScope {
                        id: contentScope
                        property bool _pointer: false
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MFocusWalk {
                            id: contentWalk
                            scope: contentScope
                            flick: pane
                        }

                        function focusFirst() {
                            if (!contentWalk.focusFirst())
                                contentScope.forceActiveFocus();
                        }

                        function arrowMove(dx: int, dy: int): bool {
                            if (SelectMenus.current)
                                return false;
                            if (contentWalk.move(dx, dy))
                                return true;
                            if (dx < 0 || dy < 0)
                                nav.focusActive();
                            return true;
                        }

                        onActiveFocusChanged: {
                            if (!contentScope.activeFocus || contentWalk.ownsFocus())
                                return;
                            if (contentScope._pointer)
                                return;
                            contentScope.focusFirst();
                        }

                        Keys.onPressed: (event) => {
                            if (SelectMenus.current)
                                return;
                            if (event.key === Qt.Key_Down)
                                contentScope.arrowMove(0, 1);
                            else if (event.key === Qt.Key_Up)
                                contentScope.arrowMove(0, -1);
                            else if (event.key === Qt.Key_Right)
                                contentScope.arrowMove(1, 0);
                            else if (event.key === Qt.Key_Left)
                                contentScope.arrowMove(-1, 0);
                            else if (event.key === Qt.Key_Home)
                                contentWalk.focusFirst(true);
                            else if (event.key === Qt.Key_End)
                                contentWalk.focusLast(true);
                            else
                                return;
                            event.accepted = true;
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Tokens.spacing.md

                            PageHeader { id: pageHeader; catalog: catalog }

                            Flickable {
                                id: pane
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                focus: false
                                contentWidth: width
                                contentHeight: sectionLoader.item
                                    ? sectionLoader.item.implicitHeight
                                    : 0
                                readonly property string pageId: Settings.sectionId
                                onPageIdChanged: contentY = 0

                                MouseArea {
                                    z: -1
                                    width: pane.width
                                    height: Math.max(pane.height, pane.contentHeight)
                                    onPressed: (mouse) => {
                                        contentScope._pointer = true;
                                        contentScope.forceActiveFocus();
                                        mouse.accepted = false;
                                        Qt.callLater(() => {
                                            contentScope._pointer = false;
                                        });
                                    }
                                }

                                Loader {
                                    id: sectionLoader
                                    width: pane.width
                                    source: Qt.resolvedUrl("sections/" + Settings.sectionId + "/Section.qml")
                                    onLoaded: {
                                        pane.contentY = 0;
                                        if (item)
                                            item.width = Qt.binding(() => sectionLoader.width);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (SelectMenus.current && SelectMenus.current.closeMenu) {
                        SelectMenus.current.closeMenu();
                        return;
                    }
                    const it = sectionLoader.item;
                    if (pageHeader.restoreOpen) {
                        pageHeader.restoreOpen = false;
                        return;
                    }
                    if (Update.open) {
                        Update.close();
                        return;
                    }
                    if (it) {
                        if (it.createOpen) {
                            it.createOpen = false;
                            return;
                        }
                        if (it.pendingLogin && String(it.pendingLogin).length > 0) {
                            it.pendingLogin = "";
                            return;
                        }
                        if (it.editorId !== undefined && String(it.editorId).length > 0) {
                            it.editorId = "";
                            return;
                        }
                        if (it.passwordOpen) {
                            it.pendingNet = null;
                            return;
                        }
                        if (it.dialogDevice) {
                            it.dialogDevice = null;
                            return;
                        }
                        if (it.pendingEdit) {
                            it.pendingEdit = null;
                            return;
                        }
                        if (it.pending) {
                            it.pending = null;
                            return;
                        }
                    }
                    Settings.close();
                }
            }

            Loader {
                anchors.fill: card
                z: 20
                active: Settings.sectionId === "bar" && sectionLoader.item
                    && !!sectionLoader.item.editorOpen
                source: Qt.resolvedUrl("sections/bar/WidgetForm.qml")
                onLoaded: {
                    item.widgetId = Qt.binding(() => sectionLoader.item ? sectionLoader.item.editorId : "");
                    item.closed.connect(() => {
                        if (sectionLoader.item)
                            sectionLoader.item.editorId = "";
                    });
                }
            }

            Loader {
                anchors.fill: card
                z: 21
                active: Update.open
                source: Qt.resolvedUrl("sections/system/UpdateOverlay.qml")
            }

        }
    }
}
