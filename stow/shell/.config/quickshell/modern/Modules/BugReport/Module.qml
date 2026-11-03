// "Report a problem" as a Hyprland toplevel (modern.bugreport). The
// screenshots are taken before this window maps; see Services/BugReport.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Connections {
        target: BugReport
        function onNotify(summary, body) {
            Notifications.toast(summary, body || "");
        }
    }

    LazyLoader {
        active: BugReport.open

        FloatingWindow {
            id: win
            visible: BugReport.open
            title: "modern.bugreport"
            color: "transparent"
            implicitWidth: Tokens.window.reportWidth
            implicitHeight: Tokens.window.reportHeight

            onVisibleChanged: {
                if (!visible && !BugReport.capturing)
                    BugReport.hide();
            }

            MWindowShell {
                anchors.fill: parent
                titleKey: "bugReport.title"
                busy: BugReport.collecting || BugReport.sending
                onClosed: BugReport.hide()

                ColumnLayout {
                    spacing: Tokens.spacing.xl

                    StepBar {
                        Layout.fillWidth: true
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: BugReport.step

                        DescribePage {}
                        ShotsPage {}
                        ReviewPage {}
                        DonePage {}
                    }

                    Footer {
                        Layout.fillWidth: true
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: BugReport.hide()
            }
        }
    }
}
