import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

PanelWindow {
    id: root

    readonly property real _edge: Config.bar.style === "floating" ? Tokens.spacing.sm : 0
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
    anchors.bottom: Config.bar.position === "bottom"
    anchors.left: true
    anchors.right: true
    implicitHeight: Config.bar.height + root._edge * 2
    exclusiveZone: Config.bar.autoHide ? 0 : implicitHeight
    color: "transparent"

    Item {
        anchors.fill: parent
        anchors.topMargin: root._edge
        anchors.bottomMargin: root._edge
        anchors.leftMargin: Tokens.spacing.sm
        anchors.rightMargin: Tokens.spacing.sm

        RowLayout {
            id: leftRow
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
