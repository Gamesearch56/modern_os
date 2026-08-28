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
                if (!visible)
                    Wallpaper.setPickerOpen(false);
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.sm

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "wallpaper.title"
                    actionKey: "wallpaper.add"
                    actionIcon: "list-add"
                    onClosed: Wallpaper.setPickerOpen(false)
                    onActionClicked: Wallpaper.importWallpaper()
                }

                GridView {
                    id: grid
                    visible: Wallpaper.images.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.floor(width / 2)
                    cellHeight: Tokens.spacing.xxl * 7
                    model: Wallpaper.images
                    currentIndex: 0
                    keyNavigationWraps: true
                    focus: true
                    delegate: MImageTile {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        source: "file://" + modelData
                        selected: grid.currentIndex === index
                        onClicked: {
                            grid.currentIndex = index;
                            Wallpaper.setWallpaper(modelData);
                        }
                    }

                    Keys.onReturnPressed: {
                        const path = Wallpaper.images[grid.currentIndex];
                        if (path)
                            Wallpaper.setWallpaper(path);
                    }
                    Keys.onEnterPressed: {
                        const path = Wallpaper.images[grid.currentIndex];
                        if (path)
                            Wallpaper.setWallpaper(path);
                    }
                }

                MEmptyState {
                    visible: Wallpaper.images.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconName: "folder-pictures-symbolic"
                    titleKey: "wallpaper.empty"
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Wallpaper.setPickerOpen(false)
            }
        }
    }
}
