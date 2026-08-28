import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    LazyLoader {
        active: Wallpaper.pickerOpen

        PanelWindow {
            visible: Wallpaper.pickerOpen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            MOverlay {
                open: Wallpaper.pickerOpen
                titleKey: "wallpaper.title"
                actionKey: "wallpaper.add"
                actionIcon: "list-add"
                cardWidth: Tokens.spacing.xxl * 22
                cardHeight: Tokens.spacing.xxl * 16
                onClosed: Wallpaper.setPickerOpen(false)
                onActionClicked: Wallpaper.importWallpaper()

                Item {
                    GridView {
                        id: grid
                        visible: Wallpaper.images.length > 0
                        anchors.fill: parent
                        clip: true
                        cellWidth: Tokens.spacing.xxl * 8
                        cellHeight: Tokens.spacing.xxl * 6
                        model: Wallpaper.images
                        delegate: MImageTile {
                            required property var modelData
                            width: grid.cellWidth
                            height: grid.cellHeight
                            source: "file://" + modelData
                            selected: modelData === Wallpaper.currentPath
                            onClicked: Wallpaper.setWallpaper(modelData)
                        }
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
        }
    }
}
