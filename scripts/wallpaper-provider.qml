import QtQuick
import QtQuick.Controls
import QtWebEngine

ApplicationWindow {
    id: win
    title: "modern.wallpaper-provider"
    visible: true
    width: 1200
    height: 800
    color: String(win.theme.color.surface || "")
    // Size matches Tokens.window.providerWidth/Height and modules/windows.lua.

    property var theme: ({
        color: ({
            primary: "#74d7ca",
            onSurface: "#ebdfe9",
            onSurfaceVariant: "#d2c2d2",
            surface: "#171118",
            surfaceContainer: "#241d25",
            outlineVariant: "#4e4350",
            error: "#ffb4ab"
        }),
        spacing: ({ xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 }),
        radius: ({ full: 9999 }),
        icon: ({ md: 24 }),
        stroke: ({ hairline: 1 }),
        interaction: ({ hover: 0.08, press: 0.12 })
    })
    property var i18n: ({ back: "Back", close: "Close" })

    function _url(): string {
        const a = Qt.application.arguments;
        for (let i = 0; i < a.length; i++) {
            const s = String(a[i]);
            if (s.indexOf("http://") === 0 || s.indexOf("https://") === 0)
                return s;
        }
        return "";
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

    function _applyArgs() {
        const a = Qt.application.arguments;
        for (let i = 0; i < a.length; i++) {
            const s = String(a[i]);
            if (s.charAt(0) !== "{")
                continue;
            try {
                const j = JSON.parse(s);
                if (j && j.color)
                    win.theme = j;
                if (j && j.back !== undefined)
                    win.i18n = j;
            } catch (e) {
            }
        }
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

    function _installScripts() {
        providerProfile.userScripts.collection = [{
            name: "modern-filter",
            sourceUrl: Qt.resolvedUrl("wallpaper-provider-inject.js"),
            injectionPoint: WebEngineScript.DocumentReady,
            runOnSubframes: true,
            worldId: WebEngineScript.MainWorld
        }];
    }

    header: Loader {
        id: chrome
        width: win.width
        source: Qt.resolvedUrl("wallpaper-provider-bar.qml")

        Binding {
            target: chrome.item
            property: "theme"
            value: win.theme
            when: chrome.status === Loader.Ready
        }
        Binding {
            target: chrome.item
            property: "urlText"
            value: String(web.url)
            when: chrome.status === Loader.Ready
        }
        Binding {
            target: chrome.item
            property: "canGoBack"
            value: web.canGoBack
            when: chrome.status === Loader.Ready
        }
        Binding {
            target: chrome.item
            property: "backLabel"
            value: String(win.i18n.back || "")
            when: chrome.status === Loader.Ready
        }
        Binding {
            target: chrome.item
            property: "closeLabel"
            value: String(win.i18n.close || "")
            when: chrome.status === Loader.Ready
        }
        Connections {
            target: chrome.item
            function onBackClicked() { web.goBack(); }
            function onCloseClicked() { Qt.quit(); }
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

    Component.onCompleted: {
        win._applyArgs();
        win._installScripts();
        web.url = win._url();
    }
}
