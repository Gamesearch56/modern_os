import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    LazyLoader {
        active: Wallpaper.pickerOpen

        FloatingWindow {
            id: win
            visible: Wallpaper.pickerOpen
            title: "modern.wallpaper"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 28
            implicitHeight: Tokens.spacing.xxl * 20

            onVisibleChanged: {
                if (visible) {
                    grid._pendingSync = true;
                    grid.syncFromCurrent();
                    win.requestActivate();
                } else {
                    Wallpaper.setPickerOpen(false);
                }
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

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "wallpaper.title"
                    actionKey: "wallpaper.add"
                    actionIcon: "list-add"
                    onClosed: Wallpaper.setPickerOpen(false)
                    onActionClicked: Wallpaper.importWallpaper()
                }

                MPane {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    PickerGrid {
                        id: grid
                        anchors.fill: parent
                        visible: Wallpaper.images.length > 0
                    }

                    MEmptyState {
                        visible: Wallpaper.images.length === 0
                        anchors.fill: parent
                        iconName: "folder-pictures-symbolic"
                        titleKey: "wallpaper.empty"
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Wallpaper.setPickerOpen(false)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Left"
                onActivated: grid.moveBy(-1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Right"
                onActivated: grid.moveBy(1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Up"
                onActivated: grid.moveBy(-grid.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Down"
                onActivated: grid.moveBy(grid.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Return"
                onActivated: grid.activate()
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0
                sequence: "Enter"
                onActivated: grid.activate()
            }
        }
    }
}
