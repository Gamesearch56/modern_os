import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root

    property var barScreen: null
    readonly property int count: Hypr.taskbarCount(root.barScreen)

    visible: root.count > 0
    implicitWidth: root.visible ? row.implicitWidth : 0
    implicitHeight: Tokens.spacing.xl

    Row {
        id: row
        spacing: Tokens.spacing.xxs

        Repeater {
            model: Hypr.toplevels

            Item {
                id: chip
                required property var modelData
                readonly property int wsId: modelData.workspace ? Number(modelData.workspace.id) : 0
                visible: chip.wsId > 0 && Hypr.isActiveOnScreen(root.barScreen, chip.wsId)
                width: visible ? Tokens.spacing.xl : 0
                height: Tokens.spacing.xl

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: modelData.activated ? Chrome.navSelected.bg : Chrome.navIdle.bg
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: Colors.color.primary
                    opacity: modelData.activated ? 0 : Chrome.stateLayer(hit.containsMouse, false)
                }

                IconImage {
                    anchors.centerIn: parent
                    width: Tokens.icon.sm
                    height: Tokens.icon.sm
                    implicitSize: Tokens.icon.sm
                    source: Quickshell.iconPath(modelData.lastIpcObject?.class ?? "application-x-executable", true)
                    asynchronous: true
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    z: 2
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            const next = !menu.open;
                            Popups.closeRequested();
                            menu.open = next;
                        } else {
                            menu.open = false;
                            Hypr.focusWindow(modelData.address);
                        }
                    }
                }

                BarPopup {
                    id: menu
                    open: false
                    width: Tokens.spacing.xxl * 8
                    height: Tokens.spacing.xxl + Tokens.spacing.md * 4

                    MListItem {
                        anchors.fill: parent
                        iconName: "window-close-symbolic"
                        titleKey: "bar.close"
                        onClicked: {
                            menu.open = false;
                            Hypr.closeWindow(modelData.address);
                        }
                    }
                }
            }
        }
    }
}
