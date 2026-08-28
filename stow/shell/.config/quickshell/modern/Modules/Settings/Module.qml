// Settings as a Hyprland toplevel. Super+Q closes it as killactive.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Catalog { id: catalog }

    LazyLoader {
        active: Settings.open

        FloatingWindow {
            id: win
            visible: Settings.open
            title: "modern.settings"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 32 + Tokens.spacing.lg
            implicitHeight: Tokens.spacing.xxl * 22 + Tokens.spacing.lg

            onVisibleChanged: {
                if (!visible)
                    Settings.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.color.surface
                radius: Tokens.radius.medium
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.md

                    ColumnLayout {
                        Layout.preferredWidth: Tokens.spacing.xxl * 8
                        spacing: Tokens.spacing.xs

                        MText {
                            key: "settings.title"
                            styleName: "headlineSmall"
                        }

                        MText {
                            value: User.displayName
                            styleName: "bodySmall"
                            color: Colors.color.onSurfaceVariant
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MIconButton {
                        close: true
                        iconName: "window-close"
                        onClicked: Settings.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.lg

                    Rectangle {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true
                        radius: Tokens.radius.medium
                        color: Colors.color.surfaceContainer

                        Nav {
                            anchors.fill: parent
                            anchors.margins: Tokens.spacing.sm
                            catalog: catalog
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.md

                        PageHeader { catalog: catalog }

                        Flickable {
                            id: pane
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: {
                                const it = sectionLoader.item;
                                if (!it)
                                    return 0;
                                return Math.max(it.implicitHeight, it.childrenRect.height);
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

            Shortcut {
                sequence: "Escape"
                onActivated: Settings.close()
            }
        }
    }
}
