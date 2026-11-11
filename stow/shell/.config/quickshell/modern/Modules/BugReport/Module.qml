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
                id: shell
                anchors.fill: parent
                titleKey: "bugReport.title"
                busy: BugReport.collecting || BugReport.sending
                onClosed: BugReport.hide()

                ColumnLayout {
                    id: form
                    spacing: Tokens.spacing.xl

                    // The editors are not tab stops, so Tab and the arrow
                    // keys walk the steps, choices, and footer from here.
                    readonly property Flickable scroll: {
                        if (BugReport.step === 0)
                            return describe;
                        if (BugReport.step === 1)
                            return shotsPage.scroll;
                        if (BugReport.step === 2)
                            return reviewPage.scroll;
                        return null;
                    }

                    MFocusWalk {
                        id: walk
                        scope: shell
                        flick: form.scroll
                    }

                    MFocusWalk {
                        id: pageWalk
                        scope: pages
                        flick: form.scroll
                    }

                    function arrowMove(dx: int, dy: int): bool {
                        return walk.move(dx, dy);
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down)
                            event.accepted = form.arrowMove(0, 1);
                        else if (event.key === Qt.Key_Up)
                            event.accepted = form.arrowMove(0, -1);
                        else if (event.key === Qt.Key_Right)
                            event.accepted = form.arrowMove(1, 0);
                        else if (event.key === Qt.Key_Left)
                            event.accepted = form.arrowMove(-1, 0);
                        else if (event.key === Qt.Key_Home)
                            event.accepted = walk.focusFirst(true);
                        else if (event.key === Qt.Key_End)
                            event.accepted = walk.focusLast(true);
                    }

                    Connections {
                        target: BugReport
                        function onStepChanged() {
                            Qt.callLater(() => {
                                if (walk.ownsFocus())
                                    return;
                                if (!pageWalk.focusFirst(true))
                                    walk.focusLast(true);
                            });
                        }
                    }

                    StepBar {
                        Layout.fillWidth: true
                    }

                    StackLayout {
                        id: pages
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: BugReport.step

                        DescribePage { id: describe }
                        ShotsPage { id: shotsPage }
                        ReviewPage { id: reviewPage }
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
