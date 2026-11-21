import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

// Full-screen layer, not a floating card: the swipe has to fade
// the desktop itself, and a sized Hyprland window cannot track a finger.
Scope {
    LazyLoader {
        active: Overview.open

        PanelWindow {
            id: win
            screen: Overview.screen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            // Default namespace is quickshell, which is the layer the
            // compositor already blurs. A separate name would skip that frost.
            WlrLayershell.layer: WlrLayer.Overlay

            Stage {
                id: stage
                anchors.fill: parent
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(win, win.screen)
                active: !Overview.tracking && Overview.progress > 0.5
                // Turning the grab off to follow a swipe also clears it.
                // That is not the user leaving the overview.
                onCleared: {
                    if (Overview.tracking || Overview.progress <= 0.5)
                        return;
                    Overview.dismiss();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Overview.dismiss()
            }
            Shortcut {
                sequence: "Left"
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(-1)
            }
            Shortcut {
                sequence: "Right"
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(1)
            }
            Shortcut {
                sequence: "Up"
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(-stage.columns)
            }
            Shortcut {
                sequence: "Down"
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(stage.columns)
            }
            Shortcut {
                sequence: "Tab"
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(1)
            }
            Shortcut {
                sequences: ["Shift+Tab", "Backtab"]
                context: Qt.ApplicationShortcut
                onActivated: stage.moveBy(-1)
            }
            Shortcut {
                sequence: "Return"
                context: Qt.ApplicationShortcut
                onActivated: stage.activate()
            }
            Shortcut {
                sequence: "Enter"
                context: Qt.ApplicationShortcut
                onActivated: stage.activate()
            }

        }
    }
}
