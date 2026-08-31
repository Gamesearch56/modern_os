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
    color: String(win.theme.color.surface || "")
    // Size matches Tokens.window.providerWidth/Height and modules/windows.lua.
    // Chrome lives in header so the WebEngine native surface cannot cover it.

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
    property var i18n: ({ back: "Back", forward: "Forward", close: "Close" })

    readonly property real chromePad: Number((win.theme.spacing || {}).sm || 8)
    readonly property real chromeBtn: Number((win.theme.spacing || {}).xxl || 32)
    readonly property real chromeHair: Number((win.theme.stroke || {}).hairline || 1)
    readonly property real chromeHeight: win.chromePad * 2 + win.chromeBtn + win.chromeHair

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

    header: Rectangle {
        implicitHeight: win.chromeHeight
        height: win.chromeHeight
        color: String(win.theme.color.surfaceContainer || "#241d25")

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: win.chromeHair
            color: String(win.theme.color.outlineVariant || "#4e4350")
        }

        RowLayout {
            anchors.fill: parent
            anchors.bottomMargin: win.chromeHair
            anchors.leftMargin: Number((win.theme.spacing || {}).lg || 16)
            anchors.rightMargin: Number((win.theme.spacing || {}).lg || 16)
            spacing: Number((win.theme.spacing || {}).xs || 4)

            NavBtn {
                glyph: "\u2190"
                label: String(win.i18n.back || "")
                ink: String(win.theme.color.onSurface || "#ebdfe9")
                fill: String(win.theme.color.outlineVariant || "#4e4350")
                enabled: web.canGoBack
                onClicked: web.goBack()
            }
            NavBtn {
                glyph: "\u2192"
                label: String(win.i18n.forward || "")
                ink: String(win.theme.color.onSurface || "#ebdfe9")
                fill: String(win.theme.color.outlineVariant || "#4e4350")
                enabled: web.canGoForward
                onClicked: web.goForward()
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Number((win.theme.spacing || {}).xl || 24)
                elide: Text.ElideRight
                text: String(web.url)
                color: String(win.theme.color.onSurfaceVariant || "#d2c2d2")
                font.pixelSize: Number((win.theme.spacing || {}).md || 12)
                verticalAlignment: Text.AlignVCenter
                Accessible.ignored: true
            }
            NavBtn {
                glyph: "\u00D7"
                label: String(win.i18n.close || "")
                ink: String(win.theme.color.error || "#ffb4ab")
                fill: String(win.theme.color.error || "#ffb4ab")
                fillOpacity: 0.16
                onClicked: Qt.quit()
            }
        }
    }

    component NavBtn: AbstractButton {
        id: btn
        property string glyph: ""
        property string label: ""
        property color ink
        property color fill
        property real fillOpacity: 1
        implicitWidth: win.chromeBtn
        implicitHeight: win.chromeBtn
        opacity: btn.enabled ? 1 : 0.38
        Accessible.name: btn.label
        Accessible.role: Accessible.Button
        hoverEnabled: true
        contentItem: Text {
            text: btn.glyph
            color: btn.ink
            font.pixelSize: Number((win.theme.spacing || {}).xl || 24)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Number((win.theme.radius || {}).full || 9999)
            color: btn.fill
            opacity: {
                const hover = Number((win.theme.interaction || {}).hover || 0.08);
                const press = Number((win.theme.interaction || {}).press || 0.12);
                if (btn.pressed)
                    return Math.min(1, btn.fillOpacity + press);
                if (btn.hovered && btn.enabled)
                    return Math.min(1, btn.fillOpacity + hover);
                return btn.fillOpacity;
            }
        }
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

    WebEngineProfile {
        id: providerProfile
        offTheRecord: true
        onDownloadRequested: (download) => win._saveDownload(download)
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
        sequences: ["Escape", "Ctrl+W"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }
    Shortcut {
        sequence: "Alt+Left"
        context: Qt.ApplicationShortcut
        onActivated: web.goBack()
    }
    Shortcut {
        sequence: "Alt+Right"
        context: Qt.ApplicationShortcut
        onActivated: web.goForward()
    }

    Component.onCompleted: {
        win._applyArgs();
        win._installScripts();
        web.url = win._url();
    }
}
