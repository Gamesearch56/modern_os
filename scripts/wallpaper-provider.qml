import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

ApplicationWindow {
    id: win
    title: "modern.wallpaper-provider"
    visible: true
    width: 1200
    height: 800

    function _url(): string {
        const a = Qt.application.arguments;
        for (let i = 0; i < a.length; i++) {
            const s = String(a[i]);
            if (s.indexOf("http://") === 0 || s.indexOf("https://") === 0)
                return s;
        }
        return "https://4kwallpapers.com";
    }

    function _dest(): string {
        const a = Qt.application.arguments;
        for (let i = a.length - 1; i >= 0; i--) {
            const s = String(a[i]);
            if (s.indexOf("/") === 0 && s.indexOf("http") !== 0)
                return s;
        }
        return "";
    }

    function _isImage(url): bool {
        const u = String(url || "").split("?")[0].split("#")[0].toLowerCase();
        return u.endsWith(".jpg") || u.endsWith(".jpeg") || u.endsWith(".png") || u.endsWith(".webp");
    }

    function _leavePage(url): bool {
        const u = String(url || "");
        if (win._isImage(u))
            return true;
        if (u === "about:blank" || u.indexOf("blob:") === 0)
            return true;
        return false;
    }

    function _saveDownload(download) {
        const u = download.url ? String(download.url) : "";
        const mime = download.mimeType ? String(download.mimeType) : "";
        const suggested = download.suggestedFileName ? String(download.suggestedFileName) : "";
        const image = mime.indexOf("image/") === 0 || win._isImage(u) || win._isImage(suggested);
        if (!image)
            return;
        const dest = win._dest();
        if (!dest.length)
            return;
        const name = (suggested.split("/").pop() || "wallpaper").replace(/[^A-Za-z0-9._-]+/g, "-");
        download.downloadDirectory = dest;
        download.downloadFileName = name.length ? name : "wallpaper";
        download.accept();
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            ToolButton {
                text: "←"
                enabled: web.canGoBack
                onClicked: web.goBack()
            }
            Label {
                Layout.fillWidth: true
                elide: Label.ElideRight
                text: web.url
            }
            ToolButton {
                text: "✕"
                onClicked: Qt.quit()
            }
        }
    }

    WebEngineProfile {
        id: providerProfile
        offTheRecord: true
        onDownloadRequested: (download) => win._saveDownload(download)
    }

    WebEngineView {
        id: web
        anchors.fill: parent
        url: win._url()
        profile: providerProfile
        onNavigationRequested: (request) => {
            if (request.isMainFrame && win._leavePage(request.url))
                request.action = WebEngineNavigationRequest.IgnoreRequest;
        }
        onNewWindowRequested: (request) => request.openIn(hopper)
    }

    WebEngineView {
        id: hopper
        visible: false
        width: 64
        height: 64
        profile: providerProfile
        onNewWindowRequested: (request) => request.openIn(hopper)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }
}
