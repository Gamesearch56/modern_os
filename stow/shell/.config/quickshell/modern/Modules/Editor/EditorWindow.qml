import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// One Texteditor window: header with the file name and menus, the find
// bar, the page, and the status bar. The compositor title carries the
// file name, so the taskbar and Overview show which file this is.
FloatingWindow {
    id: win

    property var module: null
    property bool askOnShow: false
    readonly property bool _dialog: unsaved.open || ask.open || saveAs.open || goTo.open

    title: I18n.t("editor.windowTitle", { name: win._shownName })
    readonly property string _shownName: EditorDoc.dirty ? I18n.t("editor.dirtyName", { name: EditorDoc.name }) : EditorDoc.name
    color: "transparent"
    implicitWidth: Tokens.window.editorWidth
    implicitHeight: Tokens.window.editorHeight
    minimumSize: Qt.size(Tokens.spacing.xxl * 12, Tokens.spacing.xxl * 8)

    onClosed: win.module.windowClosed(pane.edit.text)
    // A closed dialog keeps the key focus it took, so typing would go nowhere.
    on_DialogChanged: {
        if (!win._dialog)
            Qt.callLater(() => pane.focusText());
    }

    Component.onCompleted: {
        pane.focusText();
        if (win.askOnShow)
            Qt.callLater(() => flow.close());
    }

    Item {
        anchors.fill: parent

        MWindowShell {
            anchors.fill: parent
            titleValue: win._shownName
            subtitleValue: EditorDoc.folder.length ? XdgDirs.toTilde(EditorDoc.folder) : I18n.t("editor.notSaved")
            iconName: "modern-editor-symbolic"
            busy: EditorDoc.busy
            onClosed: flow.close()

            trailing: MenuRow {
                id: menus
                actions: actions
            }

            ColumnLayout {
                spacing: Tokens.spacing.sm

                FindBar {
                    id: findBar
                    Layout.fillWidth: true
                    pane: pane
                }

                TextPane {
                    id: pane
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    actions: actions
                    onFilesDropped: (urls) => flow.openDropped(urls)
                }

                StatusBar {
                    visible: EditorPrefs.statusBar
                    Layout.fillWidth: true
                    pane: pane
                    actions: actions
                }
            }
        }

        UnsavedDialog {
            id: unsaved
        }
        AskDialog {
            id: ask
        }
        SaveAsDialog {
            id: saveAs
        }
        GoToDialog {
            id: goTo
            pane: pane
        }
    }

    Actions {
        id: actions
        pane: pane
        findBar: findBar
        flow: flow
        goTo: goTo
    }

    DocFlow {
        id: flow
        module: win.module
        pane: pane
        unsaved: unsaved
        ask: ask
        saveAsDialog: saveAs
    }

    KeyBindings {
        actions: actions
        armed: !win._dialog
    }
}
