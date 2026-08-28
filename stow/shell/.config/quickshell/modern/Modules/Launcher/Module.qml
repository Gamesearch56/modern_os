import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    IpcHandler {
        target: "launcher"
        function toggle() { Launcher.toggle(); }
        function show() { Launcher.show(); }
        function hide() { Launcher.hide(); }
    }

    LazyLoader {
        active: Launcher.open

        PanelWindow {
            id: win
            visible: Launcher.open
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
                MouseArea {
                    anchors.fill: parent
                    onClicked: Launcher.hide()
                }
            }

            MCard {
                id: card
                level: 3
                width: Math.min(Tokens.spacing.xxl * 16, win.width - Tokens.spacing.xxl)
                height: Tokens.spacing.xxl * 14
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Tokens.spacing.xxl * 3
                scale: Launcher.open ? 1 : 0.94

                Behavior on scale {
                    SpringAnimation {
                        spring: Motion.springBouncy.spring
                        damping: Motion.springBouncy.damping
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    MTextField {
                        id: query
                        Layout.fillWidth: true
                        placeholderKey: "launcher.placeholder"
                        Component.onCompleted: forceActiveFocus()
                        onAccepted: results.activateFirst()
                    }

                    MText {
                        visible: query.text.length === 0
                        key: "launcher.mostUsed"
                        styleName: "labelLarge"
                        color: Colors.color.onSurfaceVariant
                    }

                    ListView {
                        id: results
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: Launcher.query(query.text)
                        currentIndex: 0
                        delegate: MListItem {
                            required property var modelData
                            required property int index
                            width: results.width
                            iconName: modelData.icon || "application-x-executable"
                            titleValue: modelData.name
                            subtitleValue: modelData.genericName || ""
                            selected: results.currentIndex === index
                            onClicked: Launcher.launch(modelData)
                        }

                        function activateFirst() {
                            if (count > 0)
                                Launcher.launch(model[0]);
                        }

                        Keys.onDownPressed: currentIndex = Math.min(count - 1, currentIndex + 1)
                        Keys.onUpPressed: currentIndex = Math.max(0, currentIndex - 1)
                    }

                    MText {
                        visible: results.count === 0 && query.text.length > 0
                        key: "launcher.noResults"
                        styleName: "bodyMedium"
                        color: Colors.color.onSurfaceVariant
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Launcher.hide()
            }
        }
    }
}
