import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Name, folder, encoding, and line endings for a new copy of the file.
// The folder comes from the file manager's folder chooser (Flow).
MDialog {
    id: root

    property string folder: ""
    property string encoding: "utf-8"
    property string eol: "lf"

    readonly property string _name: nameField.text.trim()
    readonly property bool _valid: root._name.length > 0 && root._name.indexOf("/") < 0
        && root._name !== "." && root._name !== ".." && root.folder.charAt(0) === "/"

    signal chosen(string path, string encoding, string eol)
    signal browse(string folder)

    function ask() {
        nameField.text = EditorDoc.path.length ? EditorDoc.name : I18n.t("editor.saveAs.defaultName");
        root.folder = EditorDoc.folder.length ? EditorDoc.folder : XdgDirs.documents;
        root.encoding = EditorDoc.encoding;
        root.eol = EditorDoc.eol;
        root.open = true;
        Qt.callLater(() => {
            nameField.forceActiveFocus();
            const dot = nameField.text.lastIndexOf(".");
            nameField.editor.select(0, dot > 0 ? dot : nameField.text.length);
        });
    }

    anchors.fill: parent
    wide: true
    titleKey: "editor.saveAs.title"
    confirmKey: "editor.saveAs.save"
    cancelKey: "editor.cancel"
    confirmEnabled: root._valid && !EditorDoc.busy
    busy: EditorDoc.busy
    onCancelled: root.open = false
    onConfirmed: {
        if (root._valid)
            root.chosen((root.folder === "/" ? "" : root.folder) + "/" + root._name, root.encoding, root.eol);
    }

    MField {
        Layout.fillWidth: true
        labelKey: "editor.saveAs.name"
        MTextField {
            id: nameField
            Layout.fillWidth: true
            iconName: "text-x-generic"
            placeholderKey: "editor.saveAs.namePlaceholder"
            maximumLength: 255
            onAccepted: root.confirmed()
            onEscaped: root.cancelled()
        }
    }

    MField {
        Layout.fillWidth: true
        labelKey: "editor.saveAs.folder"
        MFolderField {
            Layout.fillWidth: true
            path: XdgDirs.toTilde(root.folder)
            titleKey: "editor.saveAs.folder"
            onBrowse: root.browse(root.folder)
        }
    }

    MField {
        Layout.fillWidth: true
        labelKey: "editor.saveAs.encoding"
        MSelect {
            Layout.fillWidth: true
            value: root.encoding
            model: [
                { value: "utf-8", titleKey: "editor.encoding.utf8" },
                { value: "utf-8-bom", titleKey: "editor.encoding.utf8bom" },
                { value: "utf-16le", titleKey: "editor.encoding.utf16le" },
                { value: "utf-16be", titleKey: "editor.encoding.utf16be" },
                { value: "windows-1252", titleKey: "editor.encoding.windows1252" },
                { value: "iso-8859-1", titleKey: "editor.encoding.iso88591" }
            ]
            onSelected: (v) => root.encoding = String(v)
        }
    }

    MField {
        Layout.fillWidth: true
        labelKey: "editor.saveAs.lineEnding"
        MSelect {
            Layout.fillWidth: true
            value: root.eol
            model: [
                { value: "lf", titleKey: "editor.eol.lf" },
                { value: "crlf", titleKey: "editor.eol.crlf" },
                { value: "cr", titleKey: "editor.eol.cr" }
            ]
            onSelected: (v) => root.eol = String(v)
        }
    }
}
