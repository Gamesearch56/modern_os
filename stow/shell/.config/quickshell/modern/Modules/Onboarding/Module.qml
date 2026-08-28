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
        // ConfigWrite is the Settings writer; first-run seeds config.json
        // from the shipped default, then opens Settings for the rest.
        Settings.openAt("general", "");
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

            Rectangle {
                anchors.fill: parent
                color: Colors.color.scrim
                opacity: 0.5
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 16, parent.width - Tokens.spacing.xxl)
                height: Tokens.spacing.xxl * 12
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.lg

                    MText {
                        key: "onboarding." + root.pages[root.page]
                        styleName: "headlineSmall"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

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
