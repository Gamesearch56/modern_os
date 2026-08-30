// Settings as a Hyprland toplevel. Super+Q closes it as killactive.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
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
            implicitWidth: Tokens.spacing.xxl * 32 + Tokens.spacing.lg
            implicitHeight: Tokens.spacing.xxl * 22 + Tokens.spacing.lg

            Catalog { id: catalog }

            onVisibleChanged: {
                if (!visible)
                    Settings.close();
            }

            Rectangle {
                id: card
                anchors.fill: parent
                color: Colors.color.surface
                radius: Tokens.radius.medium
                border.color: Colors.color.outlineVariant
                border.width: Tokens.stroke.hairline
                clip: true
                opacity: Config.design.transparency ?? 0.85

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.md
                    spacing: Tokens.spacing.md

                    MWindowChrome {
                        Layout.fillWidth: true
                        titleKey: "settings.title"
                        titleColumnWidth: Tokens.spacing.xxl * 9
                        onClosed: Settings.close()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.lg

                        MPane {
                            Layout.preferredWidth: Tokens.spacing.xxl * 9
                            Layout.fillHeight: true

                            Nav {
                                anchors.fill: parent
                                catalog: catalog
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Tokens.spacing.md

                            PageHeader { id: pageHeader; catalog: catalog }

                            Flickable {
                                id: pane
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                focus: true
                                contentWidth: width
                                contentHeight: sectionLoader.item
                                    ? sectionLoader.item.implicitHeight
                                    : 0

                                MouseArea {
                                    z: -1
                                    width: pane.width
                                    height: Math.max(pane.height, pane.contentHeight)
                                    onPressed: (mouse) => {
                                        pane.forceActiveFocus();
                                        mouse.accepted = false;
                                    }
                                }

                                Loader {
                                    id: sectionLoader
                                    width: pane.width
                                    source: Qt.resolvedUrl("sections/" + Settings.sectionId + "/Section.qml")
                                    onLoaded: {
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

            Loader {
                anchors.fill: card
                z: 22
                active: Settings.sectionId === "network" && sectionLoader.item
                    && !!sectionLoader.item.passwordOpen
                source: Qt.resolvedUrl("sections/network/PasswordOverlay.qml")
                onLoaded: {
                    item.net = Qt.binding(() => sectionLoader.item ? sectionLoader.item.pendingNet : null);
                    item.closed.connect(() => {
                        if (sectionLoader.item)
                            sectionLoader.item.pendingNet = null;
                    });
                }
            }
        }
    }
}
