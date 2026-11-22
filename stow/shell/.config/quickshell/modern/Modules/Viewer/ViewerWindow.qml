import Quickshell
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "actions.js" as ActionList

// One Imageviewer window: the picture fills it, and the controls only
// show while the pointer moves inside it, rests on a control, a control
// has key focus, a menu or dialog is open, or there is nothing to show
// yet. The compositor title carries the picture's name for the taskbar
// and Overview.
FloatingWindow {
    id: win

    property var module: null
    readonly property bool _dialog: dialog.open
    readonly property bool fullscreen: !!win.screen && win.width >= win.screen.width && win.height >= win.screen.height
    readonly property bool _onControls: topHover.hovered || prevHover.hovered || nextHover.hovered
    readonly property bool chromeShown: ViewerDoc.empty || (hover.hovered && (!win._resting || win._onControls))
        || chrome.activeFocus || top.menuOpen || win._dialog
    property bool _resting: false
    property point _lastPointer: Qt.point(-1, -1)

    // Qt repeats hover events when the scene repaints; only a real move
    // counts as the user being there.
    function _moved(at: point) {
        if (at.x === win._lastPointer.x && at.y === win._lastPointer.y)
            return;
        win._lastPointer = at;
        win._resting = false;
        rest.restart();
    }

    title: ViewerDoc.empty ? I18n.t("viewer.windowTitleEmpty") : I18n.t("viewer.windowTitle", { name: ViewerDoc.name })
    color: Colors.color.surfaceContainerLowest
    implicitWidth: Tokens.window.viewerWidth
    implicitHeight: Tokens.window.viewerHeight
    minimumSize: Qt.size(Tokens.spacing.xxl * 8, Tokens.spacing.xxl * 6)

    onClosed: win.module.quit()
    on_DialogChanged: {
        if (!win._dialog)
            Qt.callLater(() => stage.forceActiveFocus());
    }
    Component.onCompleted: stage.forceActiveFocus()

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
            onPointChanged: win._moved(point.position)
            onHoveredChanged: {
                win._lastPointer = Qt.point(-1, -1);
                win._moved(point.position);
            }
        }

        Timer {
            id: rest
            interval: Motion.viewerChromeIdleMs
            onTriggered: win._resting = true
        }

        Stage {
            id: stage
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: info.visible ? info.left : parent.right
            anchors.rightMargin: info.visible ? Tokens.spacing.md : 0
            visible: !ViewerDoc.empty
        }

        InfoPanel {
            id: info
            visible: ViewerPrefs.info && !ViewerDoc.empty
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.md
            anchors.topMargin: top.height + Tokens.spacing.md * 2
            pixelWidth: stage.srcW
            pixelHeight: stage.srcH
        }

        MEmptyState {
            anchors.fill: parent
            visible: ViewerDoc.empty
            iconName: "modern-imageviewer-symbolic"
            titleKey: "viewer.empty.title"
            hintKey: "viewer.empty.hint"
            actionKey: "viewer.empty.open"
            onActionClicked: win.module.choose()
        }

        FocusScope {
            id: chrome
            anchors.fill: parent
            opacity: win.chromeShown ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.mediumMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.easingStandard
                }
            }

            TopBar {
                id: top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.spacing.md
                actions: actions
                percent: stage.percent

                HoverHandler {
                    id: topHover
                }
            }

            MIconButton {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                visible: ViewerDoc.count > 1
                iconName: "go-previous"
                key: "viewer.actions.previous"
                tip: true
                tipEdge: "right"
                onClicked: actions.run("previous")

                HoverHandler {
                    id: prevHover
                }
            }

            MIconButton {
                anchors.right: parent.right
                anchors.rightMargin: info.visible ? info.width + Tokens.spacing.md * 2 : Tokens.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                visible: ViewerDoc.count > 1
                iconName: "go-next"
                key: "viewer.actions.next"
                tip: true
                tipEdge: "left"
                onClicked: actions.run("next")

                HoverHandler {
                    id: nextHover
                }
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    ViewerDoc.open(drop.urls.map(u => String(u)));
                    drop.acceptProposedAction();
                }
            }
        }

        ViewerDialog {
            id: dialog
            onAgreed: (kind) => {
                if (kind === "trash")
                    ViewerDoc.trash(null);
            }
        }
    }

    Connections {
        target: ViewerDoc
        function onNoticeChanged() {
            if (!ViewerDoc.notice.length)
                return;
            dialog.ask("notice", Object.assign({ key: ViewerDoc.notice }, ViewerDoc.noticeParams));
            ViewerDoc.clearNotice();
        }
    }

    Actions {
        id: actions
        stage: stage
        window: win
        dialog: dialog
    }

    MActionKeys {
        model: ActionList.bindable()
        actions: actions
        armed: !win._dialog
    }
}
