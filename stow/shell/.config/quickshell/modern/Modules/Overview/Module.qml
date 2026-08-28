import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    LazyLoader {
        active: Overview.open

        PanelWindow {
            visible: Overview.open
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
                opacity: 0.45
                MouseArea {
                    anchors.fill: parent
                    onClicked: Overview.hide()
                }
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 22, parent.width - Tokens.spacing.xxl)
                height: Math.min(Tokens.spacing.xxl * 16, parent.height - Tokens.spacing.xxl * 2)
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MText { key: "overview.title"; styleName: "headlineSmall" }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: Tokens.spacing.xxl * 7
                        cellHeight: Tokens.spacing.xxl * 4
                        model: Hypr.toplevels

                        delegate: MCard {
                            required property var modelData
                            width: grid.cellWidth - Tokens.spacing.sm
                            height: grid.cellHeight - Tokens.spacing.sm
                            level: modelData.activated ? 3 : 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Tokens.spacing.xs

                                IconImage {
                                    Layout.preferredWidth: Tokens.spacing.xl
                                    Layout.preferredHeight: Tokens.spacing.xl
                                    source: Quickshell.iconPath(modelData.lastIpcObject?.class ?? "application-x-executable", true)
                                    asynchronous: true
                                }

                                MText {
                                    value: modelData.title || ""
                                    styleName: "labelLarge"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    Hypr.focusWindow(modelData.address);
                                    Overview.hide();
                                }
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Overview.hide()
            }
        }
    }
}
