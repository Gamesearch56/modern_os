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
        busy: ManualDocs.loading
        onClosed: Qt.quit()

        trailing: Row {
            spacing: Tokens.spacing.xs
            MIconButton {
                iconName: "go-previous"
                key: "manual.back"
                tip: true
                enabled: !!win.module && win.module.canGoBack
                onClicked: win.module.back()
            }
            MIconButton {
                iconName: "go-next"
                key: "manual.forward"
                tip: true
                enabled: !!win.module && win.module.canGoForward
                onClicked: win.module.forward()
            }
        }

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
    // Listing StandardKey.Back as well would register Alt+Left twice,
    // which Qt treats as ambiguous and never activates.
    Shortcut {
        sequences: ["Alt+Left", "Backspace", "Back"]
        enabled: !nav.searching
        onActivated: win.module.back()
    }
    Shortcut {
        sequences: ["Alt+Right", "Forward"]
        enabled: !nav.searching
        onActivated: win.module.forward()
    }
    // Release, not press, like Files: stepping while the grab is held
    // swallows the next click.
    TapHandler {
        parent: win.contentItem
        acceptedButtons: Qt.BackButton
        onPressedChanged: if (!pressed) Qt.callLater(() => win.module.back())
    }
    TapHandler {
        parent: win.contentItem
        acceptedButtons: Qt.ForwardButton
        onPressedChanged: if (!pressed) Qt.callLater(() => win.module.forward())
    }
}
