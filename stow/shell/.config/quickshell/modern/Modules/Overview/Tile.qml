import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MWindowTile {
    id: root

    property var win: null
    readonly property string address: root.win?.address || ""
    readonly property var _ipc: root.win?.lastIpcObject || ({})
    readonly property string _class: String(root._ipc.class || root.win?.class || root._ipc.initialClass || "")
    readonly property string _rawTitle: String(root.win?.title || root._ipc.title || "").trim()
    readonly property string _appName: {
        const n = Apps.displayNameForHint(root._class);
        return n.length ? n : (root._rawTitle.length && root._rawTitle !== "~" ? root._rawTitle : root._class);
    }
    readonly property bool _titleUseful: {
        const t = root._rawTitle;
        if (!t.length || t === "~")
            return false;
        if (t === root._appName)
            return false;
        return t.toLowerCase() !== root._class.toLowerCase();
    }
    readonly property string _workspace: {
        const raw = root.win?.workspace?.id ?? root._ipc.workspace?.id ?? root._ipc.workspace;
        const id = Number(raw);
        if (id > 0)
            return I18n.t("overview.workspace", { id: id });
        return "";
    }

    iconName: Apps.resolveIcon(root._class)
    titleValue: root._appName
    subtitleValue: root._titleUseful ? root._rawTitle : root._workspace
    captionValue: root._titleUseful ? root._workspace : ""
    previewReady: capture.hasContent

    ScreencopyView {
        id: capture
        visible: capture.hasContent
        captureSource: root.win && root.win.wayland ? root.win.wayland : null
        live: root.selected
        paintCursor: false
        anchors.centerIn: parent
        width: {
            const bw = parent ? parent.width : 0;
            const bh = parent ? parent.height : 0;
            const sw = capture.sourceSize.width;
            const sh = capture.sourceSize.height;
            if (bw <= 0 || bh <= 0)
                return 0;
            if (sw <= 0 || sh <= 0)
                return bw;
            return Math.ceil(sw * Math.max(bw / sw, bh / sh));
        }
        height: {
            const bw = parent ? parent.width : 0;
            const bh = parent ? parent.height : 0;
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
}
