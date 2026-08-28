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
            id: win
            visible: Wallpaper.pickerOpen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            Rectangle {
                anchors.fill: parent
                color: Colors.color.scrim
                opacity: 0.4
                MouseArea {
                    anchors.fill: parent
                    onClicked: Wallpaper.setPickerOpen(false)
                }
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 22, win.width - Tokens.spacing.xxl)
                height: Math.min(Tokens.spacing.xxl * 16, win.height - Tokens.spacing.xxl * 2)
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MText {
                        key: "wallpaper.title"
                        styleName: "headlineSmall"
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: Tokens.spacing.xxl * 8
                        cellHeight: Tokens.spacing.xxl * 6
                        model: Wallpaper.images
                        delegate: Item {
                            required property var modelData
                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Tokens.spacing.xs
                                radius: Tokens.radius.small
                                color: Colors.color.surfaceContainerHighest
                                border.width: modelData === Wallpaper.currentPath ? 2 : 0
                                border.color: Colors.color.primary
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData
                                    sourceSize.width: 256
                                    sourceSize.height: 256
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Wallpaper.setWallpaper(modelData)
                                }
                            }
                        }
                    }

                    MText {
                        visible: Wallpaper.images.length === 0
                        key: "wallpaper.empty"
                        styleName: "bodyMedium"
                        color: Colors.color.onSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
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
