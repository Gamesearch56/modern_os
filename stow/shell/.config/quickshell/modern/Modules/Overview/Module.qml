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

        FloatingWindow {
            visible: Overview.open
            title: "modern.overview"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 22
            implicitHeight: Tokens.spacing.xxl * 16

            onVisibleChanged: {
                if (!visible)
                    Overview.hide();
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "overview.title"
                    onClosed: Overview.hide()
                }

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
                        padding: Tokens.spacing.sm

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

            Shortcut {
                sequence: "Escape"
                onActivated: Overview.hide()
            }
        }
    }
}
