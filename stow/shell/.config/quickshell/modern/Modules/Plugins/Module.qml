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

            MOverlay {
                open: Plugins.open
                titleKey: "plugin.title"
                cardWidth: Tokens.spacing.xxl * 16
                cardHeight: Tokens.spacing.xxl * 12
                onClosed: Plugins.hide()

                ListView {
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

            Shortcut {
                sequence: "Escape"
                onActivated: Plugins.hide()
            }
        }
    }
}
