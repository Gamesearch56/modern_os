import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

PanelWindow {
    id: root

    readonly property bool vertical: Config.bar.position === "left" || Config.bar.position === "right"
    readonly property real _edge: Config.bar.style === "floating" ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0
    readonly property real _end: Config.bar.endGap ?? Tokens.spacing.sm
    readonly property var _leftIds: root._without(Config.bar.left, "taskbar")
    readonly property var _centerIds: root._without(Config.bar.center, "taskbar")
    readonly property var _rightIds: root._without(Config.bar.right, "taskbar")
    readonly property bool _taskbarOn: {
        const lists = [Config.bar.left, Config.bar.center, Config.bar.right];
        for (let i = 0; i < lists.length; i++) {
            const arr = lists[i] || [];
            for (let j = 0; j < arr.length; j++) {
                if (arr[j] === "taskbar")
                    return true;
            }
        }
        return false;
    }

    function _without(arr, id) {
        const out = [];
        const list = arr || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] !== id)
                out.push(list[i]);
        }
        return out;
    }

    anchors.top: Config.bar.position !== "bottom"
    anchors.bottom: Config.bar.position !== "top"
    anchors.left: Config.bar.position !== "right"
    anchors.right: Config.bar.position !== "left"
    implicitHeight: root.vertical ? 0 : (Config.bar.height + root._edge * 2)
    implicitWidth: root.vertical ? (Config.bar.height + root._edge * 2) : 0
    exclusiveZone: Config.bar.autoHide ? 0 : (root.vertical ? implicitWidth : implicitHeight)
    color: "transparent"

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

                BarIsland {
                    empty: root._leftIds.length === 0
                    Repeater {
                        model: root._leftIds
                        WidgetLoader {
                            barScreen: root.screen
                        }
                    }
                }

                BarIsland {
                    empty: !root._taskbarOn || taskbarLoader.item === null || taskbarLoader.item.implicitWidth < 1
                    WidgetLoader {
                        id: taskbarLoader
                        modelData: "taskbar"
                        barScreen: root.screen
                    }
                }
            }

            BarIsland {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: Config.bar.height
                empty: root._centerIds.length === 0
                Repeater {
                    model: root._centerIds
                    WidgetLoader {
                        barScreen: root.screen
                    }
                }
            }

            BarIsland {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Config.bar.height
                empty: root._rightIds.length === 0
                Repeater {
                    model: root._rightIds
                    WidgetLoader {
                        barScreen: root.screen
                    }
                }
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

                BarIsland {
                    vertical: true
                    empty: root._leftIds.length === 0
                    Repeater {
                        model: root._leftIds
                        WidgetLoader {
                            barScreen: root.screen
                        }
                    }
                }
            }

            BarIsland {
                vertical: true
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.bar.height
                empty: root._centerIds.length === 0
                Repeater {
                    model: root._centerIds
                    WidgetLoader {
                        barScreen: root.screen
                    }
                }
            }

            BarIsland {
                vertical: true
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.bar.height
                empty: root._rightIds.length === 0
                Repeater {
                    model: root._rightIds
                    WidgetLoader {
                        barScreen: root.screen
                    }
                }
            }
        }
    }
}
