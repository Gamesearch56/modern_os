import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// The Manual window: the document list on the left, the open document
// on the right. The compositor title names the document for the
// taskbar and Overview.
FloatingWindow {
    id: win

    property var module: null
    readonly property var doc: win.module ? win.module.doc : null

    title: win.doc ? I18n.t("manual.windowTitle", { name: win.doc.title }) : I18n.t("manual.title")
    color: "transparent"
    implicitWidth: Tokens.window.manualWidth
    implicitHeight: Tokens.window.manualHeight
    minimumSize: Qt.size(Tokens.spacing.xxl * 14, Tokens.spacing.xxl * 8)

    onClosed: Qt.quit()
    Component.onCompleted: Qt.callLater(() => nav.focusSearch())

    MWindowShell {
        anchors.fill: parent
        titleKey: "manual.title"
        iconName: "modern-manual-symbolic"
        titleColumnWidth: Tokens.spacing.xxl * 9
        chromeOpacity: 1
        actionKey: win.module && win.module.canGoBack ? "manual.back" : ""
        actionIcon: win.module && win.module.canGoBack ? "go-previous" : ""
        busy: ManualDocs.loading
        onClosed: Qt.quit()
        onActionClicked: win.module.back()

        RowLayout {
            spacing: Tokens.spacing.lg

            MPane {
                Layout.preferredWidth: Tokens.spacing.xxl * 9
                Layout.fillHeight: true

                Nav {
                    id: nav
                    anchors.fill: parent
                    current: win.module ? win.module.current : ""
                    onPicked: (path) => win.module.open(path)
                    onContentRequested: reader.forceActiveFocus()
                }
            }

            Reader {
                id: reader
                Layout.fillWidth: true
                Layout.fillHeight: true
                doc: win.doc
                failed: ManualDocs.failed && !ManualDocs.loading
                onLinkActivated: (link) => win.module.follow(link)
                onNavRequested: nav.focusActive()
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: nav.focusSearch()
    }
    Shortcut {
        sequences: [StandardKey.Back, "Alt+Left", "Backspace"]
        enabled: !nav.searching
        onActivated: win.module.back()
    }
}
