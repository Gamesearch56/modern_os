import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../Commons"
import "../../Widgets"
import "../../Services"

// The window itself is the card. The name sits under it, the way a
// workspace overview labels a window, in the desktop's own type and color.
Item {
    id: root

    property var win: null
    property bool selected: false

    signal clicked()
    signal hovered()

    readonly property string address: root.win?.address || ""
    readonly property var _ipc: root.win?.lastIpcObject || ({})
    readonly property string _class: String(root._ipc.class || root.win?.class || root._ipc.initialClass || "")
    readonly property string _rawTitle: String(root.win?.title || root._ipc.title || "").trim()
    readonly property string _appName: {
        // The compositor title stays modern.files so window rules still match.
        if (root._rawTitle === "modern.files")
            return I18n.t("files.launcherName");
        const n = Apps.displayNameForHint(root._class);
        return n.length ? n : (root._rawTitle.length && root._rawTitle !== "~" ? root._rawTitle : root._class);
    }
    readonly property int _workspaceId: {
        const direct = root.win && root.win.workspace ? Number(root.win.workspace.id) : 0;
        if (direct > 0)
            return direct;
        const ws = root._ipc.workspace;
        const nested = ws && ws.id !== undefined ? Number(ws.id) : Number(ws);
        return nested > 0 ? nested : 0;
    }

    Accessible.role: Accessible.Button
    Accessible.name: root._workspaceId > 0
        ? root._appName + " " + I18n.t("overview.workspace", { id: root._workspaceId })
        : root._appName
    Accessible.onPressAction: root.clicked()

    readonly property real _labelSpace: Tokens.overview.caption + Tokens.overview.labelGap

    MCard {
        id: frame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(1, parent.height - root._labelSpace)
        padding: 0
        level: root.selected ? 4 : 2
        highlighted: root.selected

        // Qt clips to the item rectangle, so the live image stays square
        // unless it is masked to the same radius as the card.
        Item {
            id: shot
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shotMask
            }

            ScreencopyView {
                id: capture
                visible: capture.hasContent
                captureSource: root.win && root.win.wayland ? root.win.wayland : null
                live: root.selected
                paintCursor: false
                anchors.centerIn: parent
                width: {
                    const bw = frame.width;
                    const bh = frame.height;
                    const sw = capture.sourceSize.width;
                    const sh = capture.sourceSize.height;
                    if (bw <= 0 || bh <= 0)
                        return 0;
                    if (sw <= 0 || sh <= 0)
                        return bw;
                    return Math.ceil(sw * Math.max(bw / sw, bh / sh));
                }
                height: {
                    const bw = frame.width;
                    const bh = frame.height;
                    const sw = capture.sourceSize.width;
                    const sh = capture.sourceSize.height;
                    if (bw <= 0 || bh <= 0)
                        return 0;
                    if (sw <= 0 || sh <= 0)
                        return bh;
                    return Math.ceil(sh * Math.max(bw / sw, bh / sh));
                }

                function _freeze() {
                    if (!capture.live && capture.captureSource)
                        capture.captureFrame();
                }

                Component.onCompleted: capture._freeze()
                onLiveChanged: capture._freeze()
                onCaptureSourceChanged: capture._freeze()
            }

            MIcon {
                anchors.centerIn: parent
                visible: !capture.hasContent
                name: Apps.resolveIcon(root._class) || "application-x-executable"
                size: Tokens.icon.lg
                tint: false
                preferSymbolic: false
            }
        }

        Item {
            id: shotMask
            visible: false
            anchors.fill: parent
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.medium
            }
        }
    }

    Row {
        anchors.top: frame.bottom
        anchors.topMargin: Tokens.overview.labelGap
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.md

        MIcon {
            name: Apps.resolveIcon(root._class) || "application-x-executable"
            size: Tokens.icon.sm
            tint: false
            preferSymbolic: false
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: Math.max(0, parent.width - Tokens.icon.sm - Tokens.spacing.md)
            spacing: Tokens.spacing.xxs

            MText {
                value: root._appName
                styleName: "labelMedium"
                color: root.selected ? Colors.color.primary : Colors.color.onSurface
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
            }

            MText {
                key: "overview.workspace"
                params: ({ id: root._workspaceId })
                visible: root._workspaceId > 0
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }

}
