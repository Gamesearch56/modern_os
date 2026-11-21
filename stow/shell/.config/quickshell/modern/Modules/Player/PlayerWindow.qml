import Quickshell
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "actions.js" as ActionList

// One Mediaplayer window: the video fills it, and the controls and the
// pointer only show while the pointer moves inside it, rests on a control,
// a control has key focus, a menu or dialog is open, a song plays, or
// nothing plays yet. The compositor title carries the file's name for the taskbar and
// Overview.
FloatingWindow {
    id: win

    property var module: null
    readonly property bool _dialog: dialog.open
    readonly property bool fullscreen: !!win.screen && win.width >= win.screen.width && win.height >= win.screen.height
    readonly property bool _onControls: topHover.hovered || barHover.hovered
    readonly property bool _song: playback.ready && !playback.hasVideo
    readonly property bool chromeShown: PlayerDoc.empty || playback.failed || win._song
        || (hover.hovered && (!win._resting || win._onControls))
        || chrome.activeFocus || top.menuOpen || bar.menuOpen || win._dialog
    property bool _resting: false
    property point _lastPointer: Qt.point(-1, -1)

    // Qt repeats hover events when the scene repaints, and a playing video
    // repaints all the time; only a real move counts as the user being there.
    function _moved(at: point) {
        if (at.x === win._lastPointer.x && at.y === win._lastPointer.y)
            return;
        win._lastPointer = at;
        win._resting = false;
        rest.restart();
    }

    title: PlayerDoc.empty ? I18n.t("player.windowTitleEmpty") : I18n.t("player.windowTitle", { name: PlayerDoc.name })
    color: PlayerDoc.empty || win._song ? Colors.color.surfaceContainerLowest : Colors.color.scrim
    implicitWidth: Tokens.window.playerWidth
    implicitHeight: Tokens.window.playerHeight
    minimumSize: Qt.size(Tokens.spacing.xxl * 10, Tokens.spacing.xxl * 6)

    onClosed: win.module.quit()
    on_DialogChanged: {
        if (!win._dialog)
            Qt.callLater(() => playback.forceActiveFocus());
    }
    Component.onCompleted: playback.forceActiveFocus()

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
            cursorShape: win.chromeShown ? Qt.ArrowCursor : Qt.BlankCursor
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

        Playback {
            id: playback
            anchors.fill: parent
            visible: !PlayerDoc.empty
            onTapped: actions.run("playPause")
            onDoubleTapped: actions.run("fullscreen")
            onWheeled: (steps) => actions.run(steps > 0 ? "volumeUp" : "volumeDown")
            onZoomed: (zoom) => osd.show(I18n.t("player.osd.zoom", { percent: Math.round(zoom * 100) }))
        }

        MEmptyState {
            anchors.fill: parent
            visible: PlayerDoc.empty
            iconName: "modern-mediaplayer-symbolic"
            titleKey: "player.empty.title"
            hintKey: "player.empty.hint"
            actionKey: "player.empty.open"
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

                HoverHandler {
                    id: topHover
                }
            }

            Controls {
                id: bar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.spacing.md
                visible: !PlayerDoc.empty
                actions: actions
                playback: playback

                HoverHandler {
                    id: barHover
                }
            }
        }

        Osd {
            id: osd
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: win.chromeShown ? top.height + Tokens.spacing.md * 2 : Tokens.spacing.lg
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    PlayerDoc.open(drop.urls.map(u => String(u)));
                    drop.acceptProposedAction();
                }
            }
        }

        MDialog {
            id: dialog
            property var params: ({})
            anchors.fill: parent
            titleKey: "player.notice.title"
            bodyKey: String(dialog.params.key || "player.errors.failed")
            bodyParams: dialog.params
            confirmKey: "player.ok"
            showCancel: false
            onConfirmed: dialog.open = false
            onCancelled: dialog.open = false
        }
    }

    Connections {
        target: PlayerDoc
        function onNoticeChanged() {
            if (!PlayerDoc.notice.length)
                return;
            dialog.params = Object.assign({ key: PlayerDoc.notice }, PlayerDoc.noticeParams);
            dialog.open = true;
            PlayerDoc.clearNotice();
        }
        function onSaved(path) {
            osd.show(I18n.t("player.osd.saved"));
        }
    }

    Actions {
        id: actions
        playback: playback
        window: win
        osd: osd
    }

    MActionKeys {
        model: ActionList.bindable()
        actions: actions
        armed: !win._dialog
    }
}
