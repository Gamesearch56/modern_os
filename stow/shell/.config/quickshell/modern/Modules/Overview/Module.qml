import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    LazyLoader {
        active: Overview.open

        FloatingWindow {
            id: win
            visible: Overview.open
            title: "modern.overview"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 22
            implicitHeight: Tokens.spacing.xxl * 16

            onVisibleChanged: {
                if (visible)
                    win.requestActivate();
                else
                    Overview.hide();
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
                    titleKey: "overview.title"
                    onClosed: Overview.hide()
                }

                MPane {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    WindowGrid {
                        id: grid
                        anchors.fill: parent
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Overview.hide()
            }
            Shortcut {
                sequence: "Left"
                onActivated: grid.moveBy(-1)
            }
            Shortcut {
                sequence: "Right"
                onActivated: grid.moveBy(1)
            }
            Shortcut {
                sequence: "Up"
                onActivated: grid.moveBy(-grid.columns)
            }
            Shortcut {
                sequence: "Down"
                onActivated: grid.moveBy(grid.columns)
            }
            Shortcut {
                sequence: "Return"
                onActivated: grid.activate()
            }
            Shortcut {
                sequence: "Enter"
                onActivated: grid.activate()
            }
        }
    }
}
