import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: root
    readonly property var pages: ["welcome", "language", "monitors", "wallpaper", "theme", "accounts", "finish"]
    property int page: 0

    function _finish() {
        FirstRun.complete();
        Settings.openAt("overview", "");
    }

    function _next() {
        if (page >= pages.length - 1)
            _finish();
        else
            page = page + 1;
    }

    LazyLoader {
        active: FirstRun.isFirstRun

        PanelWindow {
            visible: FirstRun.isFirstRun
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            MOverlay {
                open: FirstRun.isFirstRun
                titleKey: "onboarding." + root.pages[root.page]
                closeVisible: false
                cardWidth: Tokens.spacing.xxl * 16
                cardHeight: Tokens.spacing.xxl * 12

                ColumnLayout {
                    spacing: Tokens.spacing.lg

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.md

                        MButton {
                            kind: "text"
                            key: "onboarding.back"
                            enabled: root.page > 0
                            onClicked: root.page = Math.max(0, root.page - 1)
                        }
                        MButton {
                            kind: "text"
                            key: "onboarding.skip"
                            onClicked: root._finish()
                        }
                        MButton {
                            kind: "filled"
                            key: root.page >= root.pages.length - 1 ? "onboarding.finish" : "onboarding.next"
                            onClicked: root._next()
                        }
                    }
                }
            }
        }
    }
}
