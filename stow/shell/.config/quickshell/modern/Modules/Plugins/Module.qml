import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    LazyLoader {
        active: Plugins.open

        PanelWindow {
            visible: Plugins.open
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
                opacity: 0.4
                MouseArea { anchors.fill: parent; onClicked: Plugins.hide() }
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 16, parent.width - Tokens.spacing.xxl)
                height: Tokens.spacing.xxl * 12
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MText { key: "plugin.title"; styleName: "headlineSmall" }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: Plugins.plugins
                        delegate: MListItem {
                            required property var modelData
                            width: ListView.view.width
                            iconName: "application-x-addon"
                            titleValue: modelData.name || modelData.id || ""
                            subtitleValue: Plugins.outputs[modelData.id] || modelData.command || ""
                        }
                    }
                }
            }

            Shortcut { sequence: "Escape"; onActivated: Plugins.hide() }
        }
    }
}
