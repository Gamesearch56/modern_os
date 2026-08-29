import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"

PanelWindow {
    id: root

    readonly property bool vertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property real _edge: Config.bar.style === "floating" ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0
    readonly property real _end: Config.bar.endGap ?? Tokens.spacing.sm
    anchors.top: Config.bar.position !== "bottom"
    anchors.bottom: Config.bar.position !== "top"
    anchors.left: Config.bar.position !== "right"
    anchors.right: Config.bar.position !== "left"
    implicitHeight: root.vertical ? 0 : (Config.bar.height + root._edge * 2)
    implicitWidth: root.vertical ? (Config.bar.height + root._edge * 2) : 0
    exclusiveZone: Config.bar.autoHide ? 0 : (root.vertical ? implicitWidth : implicitHeight)
    color: "transparent"
    focusable: Popups.openCount > 0

    Shortcut {
        sequence: "Escape"
        enabled: Popups.openCount > 0
        context: Qt.WindowShortcut
        onActivated: Popups.dismiss()
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: root.vertical ? root._end : root._edge
        anchors.bottomMargin: root.vertical ? root._end : root._edge
        anchors.leftMargin: root.vertical ? root._edge : root._end
        anchors.rightMargin: root.vertical ? root._edge : root._end

        Loader {
            anchors.fill: parent
            sourceComponent: root.vertical ? vertComp : horizComp
        }
    }

    Component {
        id: horizComp
        Item {
            anchors.fill: parent

            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Config.bar.height
                spacing: Tokens.spacing.sm

                IslandRow {
                    ids: Config.bar.left
                    barScreen: root.screen
                }
            }

            IslandRow {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                ids: Config.bar.center
                barScreen: root.screen
            }

            IslandRow {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                ids: Config.bar.right
                barScreen: root.screen
            }
        }
    }

    Component {
        id: vertComp
        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.bar.height
                spacing: Tokens.spacing.sm

                IslandRow {
                    vertical: true
                    ids: Config.bar.left
                    barScreen: root.screen
                }
            }

            IslandRow {
                vertical: true
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                ids: Config.bar.center
                barScreen: root.screen
            }

            IslandRow {
                vertical: true
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                ids: Config.bar.right
                barScreen: root.screen
            }
        }
    }
}
