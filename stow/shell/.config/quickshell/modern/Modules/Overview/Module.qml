import Quickshell
import QtQuick
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
            color: "transparent"
            implicitWidth: Tokens.window.overviewWidth
            implicitHeight: Tokens.window.overviewHeight

            onVisibleChanged: {
                if (visible)
                    win.requestActivate();
                else
                    Overview.hide();
            }

            MWindowShell {
                anchors.fill: parent
                titleKey: "overview.title"
                onClosed: Overview.hide()

                WindowGrid {
                    id: grid
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
