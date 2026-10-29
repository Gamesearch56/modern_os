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
            implicitHeight: Math.min(Tokens.window.overviewHeight, shell.implicitHeight)

            onVisibleChanged: {
                if (visible)
                    win.requestActivate();
                else
                    Overview.hide();
            }

            MWindowShell {
                id: shell
                anchors.fill: parent
                titleKey: "overview.title"
                focus: true
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Tab) {
                        grid.moveBy(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backtab) {
                        grid.moveBy(-1);
                        event.accepted = true;
                    }
                }
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
                sequence: "Tab"
                onActivated: grid.moveBy(1)
            }
            Shortcut {
                sequences: ["Shift+Tab", "Backtab"]
                onActivated: grid.moveBy(-1)
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
