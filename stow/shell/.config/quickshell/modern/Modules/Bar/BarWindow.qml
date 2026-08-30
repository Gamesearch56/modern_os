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
    readonly property bool _auto: !!(Config.bar.autoHide)
    readonly property real _strip: Tokens.spacing.xs
    readonly property bool _hold: Popups.openCount > 0
    readonly property bool _shown: !root._auto || root._peek || root._hold
    readonly property bool _expanded: !root._auto || root._shown || root._slidingOut
    readonly property string _layoutKey: String(Config.bar.position || "top")
    readonly property real _fullH: Config.bar.height + root._edge * 2
    readonly property real _fullW: Config.bar.height + root._edge * 2
    property bool _peek: false
    property bool _slidingOut: false
    property real _slide: 0

    anchors.top: Config.bar.position !== "bottom"
    anchors.bottom: Config.bar.position !== "top"
    anchors.left: Config.bar.position !== "right"
    anchors.right: Config.bar.position !== "left"
    implicitHeight: root.vertical ? 0 : (root._expanded ? root._fullH : root._strip)
    implicitWidth: root.vertical ? (root._expanded ? root._fullW : root._strip) : 0
    exclusiveZone: root._auto ? 0 : (root.vertical ? implicitWidth : implicitHeight)
    color: "transparent"
    focusable: Popups.openCount > 0

    Behavior on _slide {
        NumberAnimation {
            duration: Motion.extraLongMs
            easing.bezierCurve: Motion.easingEmphasizedDecelerate
        }
    }

    on_ShownChanged: {
        if (root._shown) {
            hideSettle.stop();
            root._slidingOut = false;
            root._slide = 0;
        } else {
            root._slidingOut = true;
            root._slide = 1;
            hideSettle.restart();
        }
    }
    on_LayoutKeyChanged: {
        layoutLoader.active = false;
        Qt.callLater(() => {
            layoutLoader.active = true;
        });
    }
    on_AutoChanged: {
        if (!root._auto) {
            hideTimer.stop();
            hideSettle.stop();
            root._peek = false;
            root._slidingOut = false;
            root._slide = 0;
        }
    }
    on_HoldChanged: {
        if (root._hold) {
            hideTimer.stop();
            root._peek = true;
        } else if (root._auto && !barHover.hovered)
            hideTimer.restart();
    }

    Component.onCompleted: {
        if (!root._shown)
            root._slide = 1;
    }

    Shortcut {
        sequence: "Escape"
        enabled: Popups.openCount > 0
        context: Qt.WindowShortcut
        onActivated: Popups.dismiss()
    }

    Timer {
        id: hideTimer
        interval: Math.max(Motion.mediumMs, 1)
        onTriggered: {
            if (!root._auto || root._hold || barHover.hovered)
                return;
            root._peek = false;
        }
    }
    Timer {
        id: hideSettle
        interval: Math.max(Motion.extraLongMs, 1)
        onTriggered: {
            if (!root._shown)
                root._slidingOut = false;
        }
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    root._peek = true;
                } else if (root._auto && !root._hold) {
                    hideTimer.restart();
                }
            }
        }

        Item {
            id: chrome
            width: parent.width
            height: parent.height
            x: root.vertical ? root._slide * (Config.bar.position === "right" ? root._fullW : -root._fullW) : 0
            y: root.vertical ? 0 : root._slide * (Config.bar.position === "bottom" ? root._fullH : -root._fullH)
            clip: true

            Loader {
                id: layoutLoader
                anchors.fill: parent
                anchors.topMargin: root._shown || root._slidingOut ? (root.vertical ? root._end : root._edge) : 0
                anchors.bottomMargin: root._shown || root._slidingOut ? (root.vertical ? root._end : root._edge) : 0
                anchors.leftMargin: root._shown || root._slidingOut ? (root.vertical ? root._edge : root._end) : 0
                anchors.rightMargin: root._shown || root._slidingOut ? (root.vertical ? root._edge : root._end) : 0
                active: true
                sourceComponent: root.vertical ? vertComp : horizComp
            }
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
