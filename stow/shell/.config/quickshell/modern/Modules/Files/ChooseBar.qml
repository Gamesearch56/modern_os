// Chooser row under the file list: the app's file types, the name to
// save under, and the button that hands the choice back.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    id: root
    // Space the list leaves free above this row.
    readonly property real reserve: root.visible ? root.implicitHeight + Tokens.spacing.md : 0
    visible: FilesChoose.active
    height: root.visible ? root.implicitHeight : 0
    spacing: Tokens.spacing.sm

    MSelect {
        visible: FilesRequest.filters.length > 1
        Layout.preferredWidth: Tokens.spacing.xxl * 5
        model: FilesRequest.filters.map((f, i) => ({ value: i, titleValue: f.name }))
        value: FilesRequest.filterIndex
        onSelected: value => FilesRequest.useFilter(Number(value))
    }

    MTextField {
        id: name
        visible: FilesChoose.kind === "save"
        Layout.fillWidth: true
        Layout.maximumWidth: Tokens.spacing.xxl * 12
        placeholderKey: "files.name"
        captureReturn: true
        captureEscape: true
        onTextEdited: FilesSaveAs.name = name.text
        onAccepted: FilesChoose.accept("")
        onEscaped: Files.hide()
        onActiveFocusChanged: Files.typing = name.focused
    }

    Item { Layout.fillWidth: true }

    MButton {
        kind: "filled"
        key: FilesChoose.useKey
        enabled: FilesChoose.ready && !FilesSaveAs.replacing
        onClicked: FilesChoose.accept("")
    }

    Connections {
        target: FilesSaveAs
        function onNameChanged() {
            if (name.text !== FilesSaveAs.name)
                name.text = FilesSaveAs.name;
        }
    }

    Connections {
        target: FilesChoose
        function onActiveChanged() { root._prime(); }
    }

    // The window is created after askFor() has already switched the chooser on.
    Component.onCompleted: root._prime()

    // The name is selected up to its extension, so typing renames and keeps the type.
    function _prime() {
        if (!FilesChoose.active || FilesChoose.kind !== "save")
            return;
        name.text = FilesSaveAs.name;
        Qt.callLater(() => {
            name.focusInput();
            const dot = name.text.lastIndexOf(".");
            name.editor.select(0, dot > 0 ? dot : name.text.length);
        });
    }
}
