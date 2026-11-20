import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"

PanelWindow {
    id: root

    readonly property bool vertical: BarLayout.position === "left" || BarLayout.position === "right"
    readonly property real _edge: BarLayout.edge
    readonly property real _end: BarLayout.endGap ?? Tokens.spacing.sm
    readonly property bool _auto: !!(BarLayout.autoHide)
    readonly property real _strip: Tokens.spacing.xs
    readonly property bool _hold: Popups.openCount > 0
    readonly property bool _cover: Hypr.focusedFullscreen
    readonly property bool _shown: !root._cover && (!root._auto || root._peek || root._hold)
    readonly property bool _expanded: !root._cover && (!root._auto || root._shown || root._slidingOut)
    readonly property string _layoutKey: String(BarLayout.position || "top")
    readonly property real _fullH: BarLayout.strip
    readonly property real _fullW: BarLayout.strip
    function slotIds(which: string): var {
        void Config.generation;
        if (which === "center")
            return (Config.bar.center || []).slice();
        if (which === "right")
            return (Config.bar.right || []).slice();
        return (Config.bar.left || []).slice();
    }

    property bool _peek: false
    property bool _slidingOut: false
    property real _slide: 0

    anchors.top: BarLayout.position !== "bottom"
    anchors.bottom: BarLayout.position !== "top"
    anchors.left: BarLayout.position !== "right"
    anchors.right: BarLayout.position !== "left"
    implicitHeight: root.vertical ? 0 : (root._expanded ? root._fullH : root._strip)
    implicitWidth: root.vertical ? (root._expanded ? root._fullW : root._strip) : 0
    exclusiveZone: root._cover ? 0 : BarLayout.exclusive
    visible: !root._cover
    // A virtual GPU draws this transparent strip as a black bar. An
    // opaque surface fill keeps the islands visible; a desktop GPU
    // still sees the wallpaper through the gaps.
    color: Chrome.softwareGpu ? Colors.color.surface : "transparent"
    focusable: Popups.active !== null

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
        Popups.registerBar(root);
        if (!root._shown)
            root._slide = 1;
    }
    Component.onDestruction: Popups.unregisterBar(root)

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
            cursorShape: undefined
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
            x: root.vertical ? root._slide * (BarLayout.position === "right" ? root._fullW : -root._fullW) : 0
            y: root.vertical ? 0 : root._slide * (BarLayout.position === "bottom" ? root._fullH : -root._fullH)
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
                height: BarLayout.height
                spacing: Tokens.spacing.sm

                IslandRow {
                    ids: root.slotIds("left")
                    barScreen: root.screen
                }
            }

            IslandRow {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                ids: root.slotIds("center")
                barScreen: root.screen
            }

            IslandRow {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                ids: root.slotIds("right")
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
                width: BarLayout.height
                spacing: Tokens.spacing.sm

                IslandRow {
                    vertical: true
                    ids: root.slotIds("left")
                    barScreen: root.screen
                }
            }

            IslandRow {
                vertical: true
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                ids: root.slotIds("center")
                barScreen: root.screen
            }

            IslandRow {
                vertical: true
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                ids: root.slotIds("right")
                barScreen: root.screen
            }
        }
    }
}
