import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    IpcHandler {
        target: "cheatsheet"
        function toggle() { Cheatsheet.toggle(); }
        function show() { Cheatsheet.show(); }
        function hide() { Cheatsheet.hide(); }
    }

    readonly property var categories: ({
        applications: ["launcher", "terminal", "browser", "fileManager", "spotify", "settings", "wallpaperPicker", "overview"],
        system: ["cheatsheet", "powerMenu", "exitSession", "gameMode"],
        utilities: ["clipboardHistory"],
        screenshots: ["screenshotRegion", "screenshotWindow", "screenshotFull", "colorPicker"],
        windowManagement: ["closeWindow", "fullscreen", "toggleFloating", "pseudoTile", "toggleSplit", "moveFocusLeft", "moveFocusRight", "moveFocusUp", "moveFocusDown", "moveWindowLeft", "moveWindowRight", "moveWindowUp", "moveWindowDown"],
        workspaces: ["workspace1", "workspace2", "workspace3", "workspace4", "workspace5", "workspace6", "workspace7", "workspace8", "workspace9", "workspace10", "moveToWorkspace1", "moveToWorkspace2", "moveToWorkspace3", "moveToWorkspace4", "moveToWorkspace5", "moveToWorkspace6", "moveToWorkspace7", "moveToWorkspace8", "moveToWorkspace9", "moveToWorkspace10"]
    })

    LazyLoader {
        active: Cheatsheet.open

        PanelWindow {
            visible: Cheatsheet.open
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
                MouseArea { anchors.fill: parent; onClicked: Cheatsheet.hide() }
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 22, parent.width - Tokens.spacing.xxl)
                height: Math.min(Tokens.spacing.xxl * 18, parent.height - Tokens.spacing.xxl * 2)
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MText { key: "cheatsheet.title"; styleName: "headlineSmall" }

                    MTextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderKey: "cheatsheet.search"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: CheatsheetModel.rows(search.text)
                        spacing: Tokens.spacing.xs
                        section.property: "category"
                        section.delegate: MText {
                            required property string section
                            key: "cheatsheet.category." + section
                            styleName: "titleSmall"
                            color: Colors.color.primary
                        }

                        delegate: RowLayout {
                            required property var modelData
                            width: ListView.view.width
                            spacing: Tokens.spacing.md

                            Row {
                                Layout.preferredWidth: Tokens.spacing.xxl * 8
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Tokens.spacing.xs
                                Repeater {
                                    model: modelData.caps
                                    Rectangle {
                                        required property string modelData
                                        radius: Tokens.radius.small
                                        color: Colors.color.surfaceContainerHighest
                                        implicitWidth: cap.implicitWidth + Tokens.spacing.sm * 2
                                        implicitHeight: cap.implicitHeight + Tokens.spacing.xs

                                        MText {
                                            id: cap
                                            anchors.centerIn: parent
                                            value: modelData
                                            styleName: "labelMedium"
                                            familyRole: "monospace"
                                        }
                                    }
                                }
                            }

                            MText {
                                key: "cheatsheet.action." + modelData.action
                                styleName: "bodyMedium"
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Shortcut { sequence: "Escape"; onActivated: Cheatsheet.hide() }
        }
    }
}
